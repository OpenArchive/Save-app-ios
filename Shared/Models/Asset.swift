//
//  Asset.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import LegacyUTType
import YapDatabase
import CommonCrypto
import AVFoundation
import CoreMedia
import Photos

/**
 Representation of a file asset in the database.
*/
class Asset: NSObject, Item, YapDatabaseRelationshipNode, Encodable {

    // MARK: Item

    static let collection = "assets"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Asset", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Asset")
    }

    func compare(_ rhs: Asset) -> ComparisonResult {
        return created.compare(rhs.created)
    }


    // MARK: Asset

    static let defaultMimeType = "application/octet-stream"

    /*
     A tag which is used as a generic flag.
    */
    static let flag = "Significant Content"

    let id: String
    let created: Date
    private var _uti: String
    private var _filename: String?
    var title: String?
    var desc: String?
    var location: String?
    var tags: [String]?
    var notes: String?
    var phassetId: String?
    var phImageRequestId: PHImageRequestID
    private(set) var publicUrl: URL?
    var isReady = false {
        didSet {
            if isReady {
                phImageRequestId = PHInvalidImageRequestID
            }
        }
    }
    private(set) var isUploaded = false
    private(set) var collectionId: String?

    var author: String? {
        if let space = collection?.project.space {
            var author = [String]()

            if let name = space.authorName {
                author.append(name)
            }

            if let role = space.authorRole {
                author.append(role)
            }

            if let other = space.authorOther {
                author.append(other)
            }

            if author.count > 0 {
                return author.joined(separator: ", ")
            }
        }

        return nil
    }

    var license: String? {
        collection?.project.license
    }

    private var _collection: Collection?
    var collection: Collection? {
        get {
            if _collection == nil,
                let id = collectionId {

                Db.bgRwConn?.read { transaction in
                    self._collection = transaction.object(forKey: id, inCollection: Collection.collection) as? Collection
                }
            }

            return _collection
        }
        set {
            collectionId = newValue?.id
            _collection = newValue
        }
    }

    /**
     Shortcut for `.collection.project`.
    */
    var project: Project? {
        collection?.project
    }

    /**
     Shortcut for `.project.space`.
     */
    var space: Space? {
        project?.space
    }

    var uti: any UTTypeProtocol {
        get {
            LegacyUTType(_uti)
        }
        set {
            _uti = newValue.identifier
        }
    }

    /**
     The MIME equivalent to the stored `uti` or "application/octet-stream" if the UTI has no MIME type.

     See [Wikipedia](https://en.wikipedia.org/wiki/Uniform_Type_Identifier) about UTIs.
     */
    var mimeType: String {
        uti.preferredMIMEType ?? Self.defaultMimeType
    }

    /**
     The stored filename, if any stored, or a made up filename, which uses the `id` and
     a typical extension for that `uti`.
    */
    var filename: String {
        get {
            if let filename = _filename {
                return filename
            }

            if let ext = uti.preferredFilenameExtension {
                return "\(id).\(ext)"
            }

            return id
        }
        set {
            _filename = newValue
        }
    }

    var file: URL? {
        get {
            let file = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent(id)

            // We need a file extension in order to have AVAssetImageGenerator be able
            // to recognize video formats and generate a thumbnail.
            // See AssetFactory#createThumbnail
            if let ext = uti.preferredFilenameExtension {
                return file?.appendingPathExtension(ext)
            }

            return file
        }
    }

    private var _filesize: Int64?
    /**
     The size of the attached file in bytes, if file exists and attributes can
     be read, otherwise a recorded value, from when a file was still around.
    */
    var filesize: Int64? {
        if let size = file?.size {
            _filesize = Int64(size)
        }

        return _filesize
    }

    private var _digest: Data?
    /**
     A SHA256 hash of the file content, if file can be read.

     Uses a 1 MByte buffer to keep RAM usage low.
    */
    var digest: Data? {
        if _digest == nil,
            let url = file,
            let fh = try? FileHandle(forReadingFrom: url) {

            defer {
                fh.closeFile()
            }

            var context = CC_SHA256_CTX()
            CC_SHA256_Init(&context)

            let data = fh.readData(ofLength: 1024 * 1024)

            if data.count > 0 {
                data.withUnsafeBytes {
                    if let pointer = $0.baseAddress {
                        _ = CC_SHA256_Update(&context, pointer, UInt32(data.count))
                    }
                }
            }

            _digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            _digest?.withUnsafeMutableBytes {
                if let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                    _ = CC_SHA256_Final(pointer, &context)
                }
            }
        }

        return _digest
    }

    var thumb: URL? {
        get {
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent("\(id).thumb")
        }
    }

    var flagged: Bool {
        get {
            return tags?.contains(Asset.flag) ?? false
        }
        set {
            if newValue {
                if tags == nil {
                    tags = [Asset.flag]
                }
                else if !tags!.contains(Asset.flag) {
                    tags?.append(Asset.flag)
                }
            }
            else if tags?.contains(Asset.flag) ?? false {
                tags?.removeAll { $0 == Asset.flag }

                if tags?.count ?? 0 < 1 {
                    tags = nil
                }
            }
        }
    }

    /**
     Checks, if asset is currently in an upload queue and *not* paused.

     Be careful, this is an expensive check! Cache, if you need to reuse!
    */
    var isUploading: Bool {
        var isUploading = false

        Db.bgRwConn?.read { transaction in
            transaction.iterateKeysAndObjects(inCollection: Upload.collection) { (key, upload: Upload, stop) in
                if upload.assetId == self.id && !upload.paused {
                    isUploading = true
                    stop = true
                }
            }
        }

        return isUploading
    }

    /**
     Checks, if asset is audio or video.
     */
    var isAv: Bool {
        uti.conforms(to: .audiovisualContent)
    }

    private var _duration: TimeInterval?

    /**
     The duration of a audio/video file.
     */
    var duration: TimeInterval? {
        if isAv,
           let file = file,
           file.exists
        {
            let avAsset = AVAsset(url: file)

            _duration = CMTimeGetSeconds(avAsset.duration)
        }

        return _duration
    }

    /**
     The `PHAsset` this `Asset` was created from, if any.
     */
    var phAsset: PHAsset? {
        guard let phassetId = phassetId else {
            return nil
        }

        let options = PHFetchOptions()
        options.fetchLimit = 1
        options.includeHiddenAssets = true

        return PHAsset.fetchAssets(withLocalIdentifiers: [phassetId], options: options).firstObject
    }

    var isImporting: Bool {
        !isReady && phImageRequestId != PHInvalidImageRequestID
    }


    init(_ collection: Collection, uti: any UTTypeProtocol = LegacyUTType.data,
         id: String = UUID().uuidString, created: Date = Date())
    {
        self.id = id
        self.created = created
        self._uti = uti.identifier
        self.collectionId = collection.id

        phImageRequestId = PHInvalidImageRequestID
    }


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true

    required init(coder decoder: NSCoder) {
        id = decoder.decodeObject(of: NSString.self, forKey: "id") as? String ?? UUID().uuidString
        created = decoder.decodeObject(of: NSDate.self, forKey: "created") as? Date ?? Date()
        _uti = decoder.decodeObject(of: NSString.self, forKey: "uti")! as String
        _filename = decoder.decodeObject(of: NSString.self, forKey: "filename") as? String
        title = decoder.decodeObject(of: NSString.self, forKey: "title") as? String
        desc = decoder.decodeObject(of: NSString.self, forKey: "desc") as? String
        location = decoder.decodeObject(of: NSString.self, forKey: "location") as? String
        notes = decoder.decodeObject(of: NSString.self, forKey: "notes") as? String
        tags = decoder.decodeObject(of: [NSArray.self, NSString.self], forKey: "tags") as? [String]
        phassetId = decoder.decodeObject(of: NSString.self, forKey: "phassetId") as? String
        phImageRequestId = decoder.decodeInt32(forKey: "phImageRequestId")
        publicUrl = decoder.decodeObject(of: NSURL.self, forKey: "publicUrl") as? URL
        isReady = decoder.decodeBool(forKey: "isReady")
        isUploaded = decoder.decodeBool(forKey: "isUploaded")
        collectionId = decoder.decodeObject(of: NSString.self, forKey: "collectionId") as? String
        _filesize = decoder.decodeInt64(forKey: "filesize")
        _digest = decoder.decodeObject(forKey: "digest") as? Data
        _duration = decoder.decodeObject(of: NSNumber.self, forKey: "duration") as? TimeInterval
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(created, forKey: "created")
        coder.encode(_uti, forKey: "uti")
        coder.encode(_filename, forKey: "filename")
        coder.encode(title, forKey: "title")
        coder.encode(desc, forKey: "desc")
        coder.encode(location, forKey: "location")
        coder.encode(notes, forKey: "notes")
        coder.encode(tags, forKey: "tags")
        coder.encode(phassetId, forKey: "phassetId")
        coder.encode(phImageRequestId, forKey: "phImageRequestId")
        coder.encode(publicUrl, forKey: "publicUrl")
        coder.encode(isReady, forKey: "isReady")
        coder.encode(isUploaded, forKey: "isUploaded")
        coder.encode(collectionId, forKey: "collectionId")
        coder.encode(filesize ?? Int64(0), forKey: "filesize")
        coder.encode(digest, forKey: "digest")
        coder.encode(duration, forKey: "duration")
    }


    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
    }


    // MARK: Encodable

    enum CodingKeys: String, CodingKey {
        case author
        case title
        case desc = "description"
        case created = "dateCreated"
        case license = "usage"
        case location
        case notes
        case tags
        case mimeType = "contentType"
        case filesize = "contentLength"
        case filename = "originalFileName"
        case digest = "hash"
    }

    /**
     This will create the metadata which should be exported using a
     `JSONEncoder`.
    */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let author = author {
            try container.encode(author, forKey: .author)
        }

        if title != nil {
            try container.encode(title, forKey: .title)
        }

        if desc != nil {
            try container.encode(desc, forKey: .desc)
        }

        try container.encode(created, forKey: .created)

        if license != nil {
            try container.encode(license, forKey: .license)
        }

        if location != nil {
            try container.encode(location, forKey: .location)
        }

        if notes != nil {
            try container.encode(notes, forKey: .notes)
        }

        if tags != nil {
            try container.encode(tags, forKey: .tags)
        }

        try container.encode(mimeType, forKey: .mimeType)

        if let filesize = filesize {
            try container.encode(filesize, forKey: .filesize)
        }

        try container.encode(filename, forKey: .filename)

        if let digest = digest {
            // Encode as hex string.
            try container.encode(digest.map({ String(format: "%02hhx", $0) }).joined(), forKey: .digest)
        }
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), created=\(created), "
            + "uti=\(_uti), title=\(title ?? "nil"), desc=\(desc ?? "nil"), "
            + "location=\(location ?? "nil"), notes=\(notes ?? "nil"), "
            + "tags=\(tags?.description ?? "nil"), "
            + "mimeType=\(mimeType), filename=\(filename), "
            + "file=\(file?.description ?? "nil"), thumb=\(thumb?.description ?? "nil"), "
            + "phassetId=\(phassetId ?? "nil"), "
            + "publicUrl=\(publicUrl?.absoluteString ?? "nil"), "
            + "isReady=\(isReady), isUploaded=\(isUploaded)]"
    }


    // MARK: YapDatabaseRelationshipNode

    /**
     YapDatabase will delete file and thumbnail, when object is deleted from db.
    */
    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let file = file, file.exists {
            edges.append(.init(
                name: "file", destinationFileURL: file,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        if let thumb = thumb,
            FileManager.default.fileExists(atPath: thumb.path) {
            edges.append(YapDatabaseRelationshipEdge(
                name: "thumb", destinationFileURL: thumb,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        if let id = collectionId {
            edges.append(.init(
                name: "collection", destinationKey: id, collection: Collection.collection,
                nodeDeleteRules: .deleteSourceIfDestinationDeleted))
        }

        return edges
    }


    // MARK: Methods

    /**
     Returns a thumbnail image of the asset or a default image.

     In case of the asset beeing an image or video, the thumbnail should be a smaller version of
     the image, resp. a still shot of the video. In all other cases, a default image should be
     returned.

     - returns: A thumbnail `UIImage` of the asset or a default image.
    */
    func getThumbnail() -> UIImage? {
        if let thumb = thumb,
            let data = try? Data(contentsOf: thumb),
            let image = UIImage(data: data) {
            return image
        }

        return UIImage(named: "NoImage")
    }

    /**
     Asynchronously deletes this asset from the database.

     - parameter callback: Optional callback is called asynchronously on main queue after removal.
     - returns: self for fluency.
    */
    @discardableResult
    func remove(_ callback: (() -> Void)? = nil) -> Asset {
        if isImporting {
            AssetFactory.imageManager.cancelImageRequest(phImageRequestId)
        }

        Db.writeConn?.asyncReadWrite { transaction in
            transaction.removeObject(forKey: self.id, inCollection: Self.collection)

            if let callback = callback {
                DispatchQueue.main.async(execute: callback)
            }
        }

        return self
    }

    /**
     Asynchronously stores this asset into the database.

     - parameter callback: Optional callback is called asynchronously on main queue after store.
     - returns: self for fluency.
    */
    @discardableResult
    func store(_ callback: (() -> Void)? = nil) -> Asset {
        Db.writeConn?.asyncReadWrite { transaction in
            transaction.setObject(self, forKey: self.id, inCollection: Self.collection)

            if let callback = callback {
                DispatchQueue.main.async(execute: callback)
            }
        }

        return self
    }

    /**
     Sets `publicUrl` to the given value, sets `isUploaded` to true, if the argument
     is non-nil and to false, if nil and removes the actual file from the app's
     file system, in order to keep the disk usage in check.

     - parameter url: The public URL on the server, where this was uploaded to.
     - returns: self for fluency.
    */
    @discardableResult
    func setUploaded(_ url: URL?) -> Asset {
        publicUrl = url
        isUploaded = url != nil

        if isUploaded, let file = file {
            if (try? FileManager.default.removeItem(at: file)) != nil {
                // Set this to false, so in the case, that we implement a
                // re-upload, the upload isn't tried as long as there's no
                // asset file back.
                isReady = false
            }
        }

        return self
    }
}

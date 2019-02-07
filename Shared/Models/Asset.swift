//
//  Asset.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices
import YapDatabase

/**
 Representation of a file asset in the database.
*/
class Asset: NSObject, Item, YapDatabaseRelationshipNode {

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

    static let DEFAULT_MIME_TYPE = "application/octet-stream"

    let id: String
    let created: Date
    let uti: String
    private var _filename: String?
    var title: String?
    var desc: String?
    var author: String?
    var location: String?
    var tags: [String]?
    var license: String?
    var publicUrl: URL?
    var isUploaded = false
    var error: String?
    private(set) var collectionId: String


    var collection: Collection {
        get {
            var collection: Collection?

            Db.bgRwConn?.read { transaction in
                collection = transaction.object(forKey: self.collectionId, inCollection: Collection.collection) as? Collection
            }

            return collection!
        }
        set {
            collectionId = newValue.id
        }
    }

    /**
     Shortcut for `.collection.project?.space`.
     */
    var space: Space? {
        return collection.project?.space
    }

    /**
     The MIME equivalent to the stored `uti` or "application/octet-stream" if the UTI has no MIME type.

     See [Wikipedia](https://en.wikipedia.org/wiki/Uniform_Type_Identifier) about UTIs.
     */
    var mimeType: String {
        get {
            if let mimeType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?
                .takeRetainedValue() {

                return mimeType as String
            }

            return Asset.DEFAULT_MIME_TYPE
        }
    }

    /**
     Returns the stored filename, if any stored, or a made up filename, which uses the `id` and
     a typical extension for that `uti`.
    */
    var filename: String {
        get {
            if let filename = _filename {
                return filename
            }

            if let ext = Asset.getFileExt(uti: uti) {
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
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent(id)
        }
    }

    var thumb: URL? {
        get {
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup)?
                .appendingPathComponent(Asset.collection)
                .appendingPathComponent("\(id).thumb")
        }
    }

    init(_ uti: String, _ collection: Collection, id: String = UUID().uuidString, created: Date = Date()) {
        self.id = id
        self.created = created
        self.uti = uti
        self.collectionId = collection.id
    }


    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        created = decoder.decodeObject() as? Date ?? Date()
        uti = decoder.decodeObject() as! String
        _filename = decoder.decodeObject() as? String
        title = decoder.decodeObject() as? String
        desc = decoder.decodeObject() as? String
        author = decoder.decodeObject() as? String
        location = decoder.decodeObject() as? String
        tags = decoder.decodeObject() as? [String]
        license = decoder.decodeObject() as? String
        publicUrl = decoder.decodeObject() as? URL
        isUploaded = decoder.decodeObject() as? Bool ?? false
        error = decoder.decodeObject() as? String
        collectionId = decoder.decodeObject() as! String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(created)
        coder.encode(uti)
        coder.encode(_filename)
        coder.encode(title)
        coder.encode(desc)
        coder.encode(author)
        coder.encode(location)
        coder.encode(tags)
        coder.encode(license)
        coder.encode(publicUrl)
        coder.encode(isUploaded)
        coder.encode(error)
        coder.encode(collectionId)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), created=\(created), uti=\(uti), "
            + "title=\(title ?? "nil"), desc=\(desc ?? "nil"), "
            + "author=\(author ?? "nil"), location=\(location ?? "nil"), "
            + "tags=\(tags?.description ?? "nil"), license=\(license ?? "nil"), "
            + "mimeType=\(mimeType), filename=\(filename), file=\(file?.description ?? "nil"), "
            + "thumb=\(thumb?.description ?? "nil"), "
            + "publicUrl=\(publicUrl?.absoluteString ?? "nil"), "
            + "isUploaded=\(isUploaded), error=\(error ?? "nil")]"
    }


    // MARK: YapDatabaseRelationshipNode

    /**
     YapDatabase will delete file and thumbnail, when object is deleted from db.
    */
    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let file = self.file,
            FileManager.default.fileExists(atPath: file.path) {
            edges.append(YapDatabaseRelationshipEdge(
                name: "file", destinationFileURL: file,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        if let thumb = self.thumb,
            FileManager.default.fileExists(atPath: thumb.path) {
            edges.append(YapDatabaseRelationshipEdge(
                name: "thumb", destinationFileURL: thumb,
                nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        edges.append(YapDatabaseRelationshipEdge(
            name: "collection", destinationKey: collectionId, collection: Collection.collection,
            nodeDeleteRules: .deleteSourceIfDestinationDeleted))

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

    // MARK: Class methods

    /**
     See [Wikipedia](https://en.wikipedia.org/wiki/Uniform_Type_Identifier) about UTIs.

     - parameter uti: A Uniform Type Identifier
     - returns: The standard file extension or `nil` if no UTI or nothing found.
     */
    class func getFileExt(uti: String?) -> String? {
        if let uti = uti {
            if let ext = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension)?
                .takeRetainedValue() {

                return ext as String
            }
        }

        return nil
    }
}

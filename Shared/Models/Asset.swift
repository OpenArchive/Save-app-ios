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
class Asset: NSObject, NSCoding, YapDatabaseRelationshipNode {

    static let COLLECTION = "assets"
    static let DEFAULT_MIME_TYPE = "application/octet-stream"

    let id: String
    let created: Date
    let uti: String
    var title: String?
    var desc: String?
    var author: String?
    var location: String?
    var tags: [String]?
    var license: String?

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

    private var _filename: String?

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
                forSecurityApplicationGroupIdentifier: Constants.appGroup as String)?
                .appendingPathComponent(Asset.COLLECTION)
                .appendingPathComponent(id)
        }
    }

    var thumb: URL? {
        get {
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Constants.appGroup as String)?
                .appendingPathComponent(Asset.COLLECTION)
                .appendingPathComponent("\(id).thumb")
        }
    }

    private var servers = [Server]()

    init(id: String?, created: Date?, uti: String) {
        self.id = id ?? UUID().uuidString
        self.created = created ?? Date()
        self.uti = uti
    }

    convenience init(uti: String) {
        self.init(id: nil, created: nil, uti: uti)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        created = decoder.decodeObject() as? Date ?? Date()
        uti = decoder.decodeObject() as! String
        title = decoder.decodeObject() as? String
        desc = decoder.decodeObject() as? String
        author = decoder.decodeObject() as? String
        location = decoder.decodeObject() as? String
        tags = decoder.decodeObject() as? [String]
        license = decoder.decodeObject() as? String
        servers = decoder.decodeObject() as? [Server] ?? [Server]()
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(created)
        coder.encode(uti)
        coder.encode(title)
        coder.encode(desc)
        coder.encode(author)
        coder.encode(location)
        coder.encode(tags)
        coder.encode(license)
        coder.encode(servers)
    }

    // MARK: YapDatabaseRelationshipNode

    /**
     YapDatabase will delete file and thumbnail, when object is deleted from db.
    */
    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let file = self.file,
            FileManager.default.fileExists(atPath: file.path) {
            edges.append(YapDatabaseRelationshipEdge(name: "file",
                                                     destinationFileURL: file,
                                                     nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        if let thumb = self.thumb,
            FileManager.default.fileExists(atPath: thumb.path) {
            edges.append(YapDatabaseRelationshipEdge(name: "thumb",
                                                     destinationFileURL: thumb,
                                                     nodeDeleteRules: .deleteDestinationIfSourceDeleted))
        }

        return edges
    }


    // MARK: Methods

    func getServers() -> [Server] {
        return servers
    }

    /**
     - parameter serverType: The subclass to search.
     - returns: the `Server` of subclass `serverType`, if any configured.
    */
    func getServer(ofType serverType: Server.Type) -> Server? {
        return servers.first(where: { type(of: $0) == serverType })
    }

    /**
     Add a `Server` to this asset, where we want to upload to, if not added, yet.

     - parameter serverType: The subclass to use.
     - returns: the already existing or just created subclass as given.
    */
    func setServer(ofType serverType: Server.Type) -> Server {
        if let server = getServer(ofType: serverType) {
            return server
        }

        let server = serverType.init()

        servers.append(server)

        return server
    }

    /**
     Remove a `Server` from this asset, if found.

     This makes most sense, after we removed an asset from that server.

     - parameter serverType: The subclass to use.
    */
    func removeServer(ofType serverType: Server.Type) {

        if let server = getServer(ofType: serverType),
            let idx = servers.index(of: server) {

            servers.remove(at: idx)
        }
    }

    /**
     Upload this asset to the given server.

     - parameter serverType: The `Server` subclass to use.
     - parameter progress: Callback to communicate upload progress.
     - parameter done: Callback to indicate end of upload. Check server object for status!
    */
    func upload(to serverType: Server.Type, progress: @escaping Server.ProgressHandler,
                done: @escaping Server.DoneHandler) {
        let server = setServer(ofType: serverType)

        server.upload(self, progress: progress, done: done)
    }

    /**
     Remove this asset from the given server.

     - parameter serverType: The `Server` subclass to use.
     - parameter done: Callback to indicate end of removal. Check server object for status!
     */
    func remove(from serverType: Server.Type, done: @escaping Server.DoneHandler) {
        if let server = getServer(ofType: serverType) {
            server.remove(self, done: done)
        }
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
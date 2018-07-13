//
//  Asset.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices

class Asset: NSObject, NSCoding {

    static let COLLECTION = "assets"
    static let DEFAULT_MIME_TYPE = "application/octet-stream"

    let created: Date
    let mimeType: String
    var title: String?
    var desc: String?
    var author: String?
    var location: String?
    var tags: [String]?
    var license: String?

    private var servers = [Server]()

    init(created: Date?, mimeType: String?) {
        self.created = created ?? Date()
        self.mimeType = mimeType ?? Asset.DEFAULT_MIME_TYPE
    }

    convenience override init() {
        self.init(created: nil, mimeType: nil)
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        created = decoder.decodeObject() as? Date ?? Date()
        mimeType = decoder.decodeObject() as? String ?? Asset.DEFAULT_MIME_TYPE
        title = decoder.decodeObject() as? String
        desc = decoder.decodeObject() as? String
        author = decoder.decodeObject() as? String
        location = decoder.decodeObject() as? String
        tags = decoder.decodeObject() as? [String]
        license = decoder.decodeObject() as? String
        servers = decoder.decodeObject() as? [Server] ?? [Server]()
    }

    func encode(with coder: NSCoder) {
        coder.encode(created)
        coder.encode(mimeType)
        coder.encode(title)
        coder.encode(desc)
        coder.encode(author)
        coder.encode(location)
        coder.encode(tags)
        coder.encode(license)
        coder.encode(servers)
    }

    // MARK: Methods

    /**
     - returns: a unique key to identify this asset. Basically the creation timestamp.
    */
    func getKey() -> String {
        return created.description
    }

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
     - returns: The equivalent MIME type or "application/octet-stream" if no UTI or nothing found.
    */
    class func getMimeType(uti: String?) -> String {
        if let uti = uti {
            if let mimeType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?
                .takeRetainedValue() {
                
                return mimeType as String
            }
        }

        return Asset.DEFAULT_MIME_TYPE
    }

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

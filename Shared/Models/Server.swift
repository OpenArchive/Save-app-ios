//
//  Server.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 09.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Alamofire

class Server: NSObject, NSCoding {

    /**
     Callback executed when monitoring upload progress.

     - parameter server: The calling object.
     - parameter progress: Progress information.
    */
    public typealias ProgressHandler = (_ server: Server, _ progress: Progress) -> Void

    /**
     Callback executed when upload is done. Check `isUploaded` and `error` of the `Server` object
     to evaluate the success.

     - parameter server: The calling object.
    */
    public typealias DoneHandler = (_ server: Server) -> Void

    /**
     This needs to be static, otherwise the SessionManager will get destroyed during
     the request and the request will break with error -999.

     See [Getting code=-999 using custom SessionManager](https://github.com/Alamofire/Alamofire/issues/1684)
     */
    static let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.background(withIdentifier:
            "org.open-archive.OpenArchive.background")
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: configuration)
    }()

    var publicUrl: URL?

    var isUploaded = false

    var error: String?

    required override init() {
        // Just here to satisfy init using a dynamic type variable.
    }

    // MARK: NSCoding

    required init(coder decoder: NSCoder) {
        publicUrl = decoder.decodeObject() as? URL
        isUploaded = decoder.decodeObject() as? Bool ?? false
        error = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(publicUrl)
        coder.encode(isUploaded)
        coder.encode(error)
    }

    // MARK: Methods

    /**
     Subclasses need to return a pretty name to show in the UI.

     - returns: A pretty name of this server.
    */
    func getPrettyName() -> String {
        preconditionFailure("This method must be overridden.")
    }

    /**
     Subclasses need to implement this method to upload assets.

     - parameter asset: The asset to upload.
     - parameter progress: Callback to communicate upload progress.
     - parameter done: Callback to indicate end of upload. Check server object for status!
    */
    func upload(_ asset: Asset, progress: @escaping ProgressHandler, done: @escaping DoneHandler) {
        preconditionFailure("This method must be overridden.")
    }

    /**
     Subclasses need to implement this method to remove assets from server.

     - parameter asset: The asset to upload.
    */
    func remove(_ asset: Asset, done: @escaping DoneHandler) {
        preconditionFailure("This method must be overridden.")
    }

}

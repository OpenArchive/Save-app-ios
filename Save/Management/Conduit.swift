//
//  Conduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import FilesProvider

/**
 A conduit implements #upload and #remove methods to interact with a certain
 type of `Space`.
 */
class Conduit {

    /**
     A pretty-printing JSON encoder using ISO8601 date formats.
     */
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        return encoder
    }()

    /**
     Evaluate the given `Asset`s `Space` and return the correct type of `Conduit`,
     if any available.

     - parameter asset: The `Asset` the `Conduit` is for.
    */
    class func get(for asset: Asset, _ backgroundSession: URLSession, _ foregroundSession: URLSession) -> Conduit? {
        if let space = asset.space {
            if space is WebDavSpace {
                return WebDavConduit(asset, backgroundSession, foregroundSession)
            }

            if space is DropboxSpace {
                return nil //DropboxConduit(asset, backgroundSession, foregroundSession)
            }

            if space is IaSpace {
                return IaConduit(asset, backgroundSession, foregroundSession)
            }
        }

        return nil
    }

    /**
     Callback executed when upload/remove is done. Check `isUploaded` and `error`
     of the `Asset` object to evaluate the success.

     - parameter asset: The asset which was uploaded/removed.
     */
    public typealias DoneHandler = (_ asset: Asset) -> Void


    var asset: Asset

    let backgroundSession: URLSession
    let foregroundSession: URLSession

    init(_ asset: Asset, _ backgroundSession: URLSession, _ foregroundSession: URLSession) {
        self.asset = asset
        self.backgroundSession = backgroundSession
        self.foregroundSession = foregroundSession
    }


    // MARK: "Abstract" Methods

    /**
     Subclasses need to implement this method to upload assets.

     When done, subclasses need to post a `uploadManagerDone` notification with
     the `Upload.id` as the object.

     - parameter uploadId: The ID of the upload object which identifies this upload.
     - returns: Progress to track upload progress
     */
    func upload(uploadId: String) -> Progress {
        preconditionFailure("This method must be overridden.")
    }

    /**
     Subclasses need to implement this method to remove assets from server.

     - parameter asset: The asset to remove.
     */
    func remove(done: @escaping DoneHandler) {
        preconditionFailure("This method must be overridden.")
    }


    // MARK: Public Methods

    /**
     Uploads a file to a destination.

     This method deliberatly doesn't use the FilesProvider library, but URLSession
     instead, since FilesProvider's latest version fails on uploading the
     metadata for an unkown reason. Addtionally, it's easier with the background
     upload, when using URLSession directly.

     - parameter file: The file on the local file system.
     - parameter to: The destination on the WebDAV server.
     - parameter credential: The credentials to authenticate with.
     - parameter headers: Addtitional request headers.
     - parameter progress: The main progress to report on.
     */
    func upload(_ file: URL, to: URL, _ progress: Progress, credential: URLCredential? = nil,
                headers: [String: String]? = nil)
    {
        // We do basic auth ourselves, to avoid double sending of files.
        // URLSession tends to forget to send it without a challenge,
        // which is especially annoying with big files.
        let headers = addBasicAuth(headers, credential)

        let task = backgroundSession.upload(file, to: to, method: "PUT", headers: headers)

        progress.addChild(task.progress, withPendingUnitCount: progress.totalUnitCount - progress.completedUnitCount)

    }

    func upload(_ data: Data, to: URL, _ progress: Progress, _ share: Int64, credential: URLCredential? = nil,
                headers: [String: String]? = nil, _ completionHandler: SimpleCompletionHandler = nil)
    {
        // We do basic auth ourselves, to avoid double sending of files.
        // URLSession tends to forget to send it without a challenge,
        // which is especially annoying with big files.
        let headers = addBasicAuth(headers, credential)

        let task = foregroundSession.upload(
            data, to: to, method: "PUT", headers: headers,
            completionHandler: completionHandler)

        progress.addChild(task.progress, withPendingUnitCount: share)
    }

    /**
     Boilerplate reducer. Sets an error on the `userInfo` notification object,
     if any provided and posts the `.uploadManagerDone` notification.

     You can even call it like this to reduce LOCs:

     ```Swift
     return self.done(uploadId)
     ```

     - parameter uploadId: The `ID` of the tracked upload.
     - parameter error: An optional `Error`, defaults to `nil`.
     - parameter url: An optional `URL`, where the file was uploaded to. Defaults to `nil`. Will only be set if error == nil.
     */
    func done(_ uploadId: String, error: Error? = nil, url: URL? = nil) {
        var userInfo = [AnyHashable: Any]()

        if let error = error {
            userInfo[.error] = error
        }
        else if let url = url {
            userInfo[.url] = url
        }

        NotificationCenter.default.post(name: .uploadManagerDone, object: uploadId,
                                        userInfo: userInfo)
    }


    // MARK: Helper Methods


    /**
     Construct a correct URL from given path components.

     If you don't provide any components, returns an empty file URL.

     - parameter url: The base `URL` to start from. Optional, defaults to nil.
     - parameter components: 0 or more path components.
     - returns: a new `URL` object constructed from the parameters.
     */
    func construct(url: String, _ components: String...) -> URL {
        return construct(url: URL(string: url), components)
    }

    /**
     Construct a correct URL from given path components.

     If you don't provide any components, returns an empty file URL.

     - parameter url: The base `URL` to start from. Optional, defaults to nil.
     - parameter components: 0 or more path components.
     - returns: a new `URL` object constructed from the parameters.
     */
    func construct(url: URL? = nil, _ components: String...) -> URL {
        return construct(url: url, components)
    }

    /**
     Construct a correct URL from given path components.

     If you don't provide any components, returns an empty file URL.

     - parameter url: The base `URL` to start from. Optional, defaults to nil.
     - parameter components: 0 or more path components.
     - returns: a new `URL` object constructed from the parameters.
     */
    func construct(url: URL? = nil, _ components: [String]) -> URL {
        return Conduit.construct(url: url, components)
    }

    /**
     Construct a correct URL from given path components.

     If you don't provide any components, returns an empty file URL.

     - parameter url: The base `URL` to start from. Optional, defaults to nil.
     - parameter components: 0 or more path components.
     - returns: a new `URL` object constructed from the parameters.
     */
    class func construct(url: URL? = nil, _ components: [String]) -> URL {
        if let first = components.first {

            var url = url?.appendingPathComponent(first) ?? URL(fileURLWithPath: "/\(first)")

            for component in components.dropFirst() {
                url.appendPathComponent(component)
            }

            return url
        }

        return url ?? URL(fileURLWithPath: "")
    }

    /**
     Create a HTTP Basic Auth header from the provided credentials, if valid.

     - parameter headers: A headers dictionary where to add our auth header to.
     - parameter credential: Credential to use.
     - returns: nil, if headers was nil and no valid credential, otherwise a header
        dictionary with an added (potentially overwritten) "Authorization" header.
    */
    func addBasicAuth(_ headers: [String: String]?, _ credential: URLCredential?) -> [String: String]? {
        var headers = headers

        if let user = credential?.user, let password = credential?.password {
            let authorization = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()

            if let authorization = authorization {
                if headers == nil {
                    headers = [:]
                }

                headers!["Authorization"] = "Basic \(authorization)"
            }
        }

        return headers
    }


    // MARK: Errors

    enum UploadError: LocalizedError {
        case invalidConf
        case tooManyRetries
        case dropboxFileTooBig

        var errorDescription: String? {
            switch self {
            case .invalidConf:
                return NSLocalizedString("Configuration invalid.", comment: "")

            case .tooManyRetries:
                return NSLocalizedString("Failed after too many retries.", comment: "")

            case .dropboxFileTooBig:
                return NSLocalizedString("The Dropbox support can't handle files bigger than 150 MByte.", comment: "")
            }
        }
    }
}

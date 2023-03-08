//
//  Conduit.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation

/**
 A conduit implements #upload and #remove methods to interact with a certain
 type of `Space`.
 */
class Conduit {

    static let metaFileExt = "meta.json"
    static let chunkSize: Int64 = 2 * 1024 * 1024 // 2 MByte
    static let chunkFileSizeThreshold: Int64 = 10 * 1024 * 1024 // 10 MByte

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
                return DropboxConduit(asset, backgroundSession, foregroundSession)
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

     - parameter file: The file on the local file system.
     - parameter to: The destination on the WebDAV server.
     - parameter credential: The credentials to authenticate with.
     - parameter headers: Addtitional request headers.
     - parameter progress: The main progress to report on.
     */
    func upload(_ file: URL, to: URL, _ progress: Progress, pendingUnitCount: Int64? = nil, credential: URLCredential? = nil,
                headers: [String: String]? = nil)
    {
        let task = backgroundSession.upload(file, to: to, headers: headers, credential: credential)

        progress.addChild(task.progress, withPendingUnitCount: pendingUnitCount ?? (progress.totalUnitCount - progress.completedUnitCount))
    }

    func upload(_ data: Data, to: URL, _ progress: Progress, _ share: Int64, credential: URLCredential? = nil,
                headers: [String: String]? = nil, _ completionHandler: URLSession.SimpleCompletionHandler? = nil)
    {
        let task = foregroundSession.upload(
            data, to: to, headers: headers, credential: credential,
            completionHandler: completionHandler)

        progress.addChild(task.progress, withPendingUnitCount: share)
    }

    /**
     Uploads ProofMode files, if ProofMode is enabled and files are available for the current asset.

     - parameter upload: Callback which implements the actual upload of a file, which differs depending on the actual conduit.
     - parameter file: The file URL which to upload.
     - parameter ext: The ProofMode file extension which needs to get applied to the destination file name.
     */
    func uploadProofMode(_ upload: (_ file: URL, _ ext: String) -> Void) {
        guard Settings.proofMode else {
            return
        }

        for file in Asset.Files.allCases {
            guard file != .thumb else {
                continue
            }

            if let url = file.url(asset.id), url.exists {
                upload(url, file.rawValue)
            }
        }
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


    class func readChunk(_ file: URL, offset: UInt64, length: Int64) throws -> Data {
        let fh = try FileHandle(forReadingFrom: file)

        if #available(iOS 13.0, *) {
            try fh.seek(toOffset: offset)
        }
        else {
            fh.seek(toFileOffset: offset)
        }


        let chunk = fh.readData(ofLength: Int(length))

        if #available(iOS 13.0, *) {
            try fh.close()
        }
        else {
            fh.closeFile()
        }

        return chunk
    }

    // MARK: Errors

    enum UploadError: LocalizedError {
        case invalidConf
        case tooManyRetries

        var errorDescription: String? {
            switch self {
            case .invalidConf:
                return NSLocalizedString("Configuration invalid.", comment: "")

            case .tooManyRetries:
                return NSLocalizedString("Failed after too many retries.", comment: "")
            }
        }
    }
}

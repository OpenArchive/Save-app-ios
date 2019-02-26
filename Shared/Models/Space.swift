//
//  Space.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A `Space` represents the root folder of an upload destination on a WebDAV server.

 It needs to have a `url`, a `username` and a `password`.

 A `name` is optional and is only for a user's informational purposes.
 */
class Space: NSObject {

    // MARK: Item - implemented by sublcasses

    static var collection: String {
        return "spaces"
    }

    func compare(_ rhs: Space) -> ComparisonResult {
        return prettyName.compare(rhs.prettyName)
    }

    var id: String


    // MARK: Space

    /**
     Callback executed when monitoring upload progress.

     - parameter asset: The asset which is being uploaded.
     - parameter progress: Progress information.
     */
    public typealias ProgressHandler = (_ asset: Asset, _ progress: Progress) -> Void

    /**
     Callback executed when upload/remove is done. Check `isUploaded` and `error`
     of the `Asset` object to evaluate the success.

     - parameter asset: The asset which was uploaded/removed.
     */
    public typealias DoneHandler = (_ asset: Asset) -> Void

    class var defaultPrettyName: String {
        return "Unnamed".localize()
    }

    static let sessionConf: URLSessionConfiguration = {
        let conf = URLSessionConfiguration.background(withIdentifier:
            "\(Bundle.main.bundleIdentifier ?? "").background")
        conf.sharedContainerIdentifier = Constants.appGroup

        return conf
    }()

    /**
     A pretty-printing JSON encoder using ISO8601 date formats.
    */
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        return encoder
    }()


    var name: String?
    var url: URL?
    var favIcon: UIImage?
    var username: String?
    var password: String?

    var prettyName: String {
        return name ?? url?.host ?? url?.absoluteString ?? Space.defaultPrettyName
    }

    init(_ name: String? = nil, _ url: URL? = nil, _ favIcon: UIImage? = nil, _ username: String? = nil, _ password: String? = nil) {
        id = UUID().uuidString
        self.name = name
        self.url = url
        self.favIcon = favIcon
        self.username = username
        self.password = password
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        name = decoder.decodeObject() as? String
        url = decoder.decodeObject() as? URL
        favIcon = decoder.decodeObject() as? UIImage
        username = decoder.decodeObject() as? String
        password = decoder.decodeObject() as? String
    }

    @objc(encodeWithCoder:) func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
        coder.encode(url)
        coder.encode(favIcon)
        coder.encode(username)
        coder.encode(password)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), url=\(url?.description ?? "nil"), "
            + "favIcon=\(favIcon?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password ?? "nil")]"
    }


    // MARK: "Abstract" Methods

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

     - parameter asset: The asset to remove.
     */
    func remove(_ asset: Asset, done: @escaping DoneHandler) {
        preconditionFailure("This method must be overridden.")
    }


    // MARK: Helper Methods


    /**
     Construct a correct URL from given path components.

     If you don't provide any components, returns an empty file URL.

     - parameter url: The base `URL` to start from. Optional.
     - parameter components: 0 or more path components.
     - returns: a new `URL` object constructed from the parameters.
     */
    func construct(url: URL?, _ components: String...) -> URL {
        if let first = components.first {

            var url = url?.appendingPathComponent(first) ?? URL(fileURLWithPath: first)

            var components = components
            components.remove(at: 0)

            for component in components {
                url.appendPathComponent(component)
            }

            return url
        }

        return URL(fileURLWithPath: "")
    }

    /**
     Boilerplate reducer. Sets an error on the `Asset` and calls the done handler
     on the main thread.

     You can even call it like this to reduce LOCs:

     ```Swift
        return self.done(asset, nil, done)
     ```

     - parameter asset: The `Asset` to return.
     - parameter error: An optional error `String`.
     - parameter done: The `DoneHandler` callback.
    */
    func done(_ asset: Asset, _ error: String?, _ done: @escaping DoneHandler) {
        asset.error = error

        DispatchQueue.main.async {
            done(asset)
        }

        return
    }
}

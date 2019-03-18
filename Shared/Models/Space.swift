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
    var authorName: String?
    var authorRole: String?
    var authorOther: String?

    var prettyName: String {
        return name ?? url?.host ?? url?.absoluteString ?? Space.defaultPrettyName
    }

    init(name: String? = nil, url: URL? = nil, favIcon: UIImage? = nil,
         username: String? = nil, password: String? = nil,
         authorName: String? = nil, authorRole: String? = nil,
         authorOther: String? = nil) {

        id = UUID().uuidString
        self.name = name
        self.url = url
        self.favIcon = favIcon
        self.username = username
        self.password = password
        self.authorName = authorName
        self.authorRole = authorRole
        self.authorOther = authorOther
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        name = decoder.decodeObject() as? String
        url = decoder.decodeObject() as? URL
        favIcon = decoder.decodeObject() as? UIImage
        username = decoder.decodeObject() as? String
        password = decoder.decodeObject() as? String
        authorName = decoder.decodeObject() as? String
        authorRole = decoder.decodeObject() as? String
        authorOther = decoder.decodeObject() as? String
    }

    @objc(encodeWithCoder:) func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
        coder.encode(url)
        coder.encode(favIcon)
        coder.encode(username)
        coder.encode(password)
        coder.encode(authorName)
        coder.encode(authorRole)
        coder.encode(authorOther)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), url=\(url?.description ?? "nil"), "
            + "favIcon=\(favIcon?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password ?? "nil"), "
            + "authorName=\(authorName ?? "nil"), authorRole=\(authorRole ?? "nil"), "
            + "authorOther=\(authorOther ?? "nil")]"
    }


    // MARK: "Abstract" Methods

    /**
     Subclasses need to implement this method to upload assets.

     When done, subclasses need to post a `uploadManagerDone` notification with
     the `Upload.id` as the object.

     - parameter asset: The asset to upload.
     - parameter uploadId: The ID of the upload object which identifies this upload.
     - returns: Progress to track upload progress
     */
    func upload(_ asset: Asset, uploadId: String) -> Progress {
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
    class func construct(url: URL?, _ components: String...) -> URL {
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
     Boilerplate reducer. Sets an error on the `userInfo` notification object,
     if any provided, sets the URL, if any provided and posts the
     `.uploadManagerDone` notification.

     You can even call it like this to reduce LOCs:

     ```Swift
        return self.done(uploadId)
     ```

     - parameter uploadId: The `ID` of the tracked upload.
     - parameter error: An optional error `String`, defaults to `nil`.
     - parameter url: The URL the asset was uploaded to, if any. Defaults to `nil`.
    */
    func done(_ uploadId: String, _ error: String? = nil, _ url: URL? = nil) {
        var userInfo = [AnyHashable: Any]()

        if let error = error {
            userInfo[.error] = error
        }
        else {
            userInfo[.url] = url
        }

        NotificationCenter.default.post(name: .uploadManagerDone, object: uploadId,
                                        userInfo: userInfo)
    }

    /**
     Boilerplate reducer. Sets an error on the `userInfo` notification object,
     if any provided and posts the `.uploadManagerDone` notification.

     You can even call it like this to reduce LOCs:

     ```Swift
     return self.done(uploadId)
     ```

     - parameter uploadId: The `ID` of the tracked upload.
     - parameter error: An optional Error object.
     */
    func done(_ uploadId: String, _ error: Error?) {
        done(uploadId, error?.localizedDescription)
    }
}

//
//  Space.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import Alamofire

class InvalidConfError: NSError {
    init() {
        super.init(domain: String(describing: Space.self), code: -123,
                   userInfo: [NSLocalizedDescriptionKey: "Configuration invalid.".localize()])
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
}


/**
 A `Space` represents the root folder of an upload destination on a WebDAV server.

 It needs to have a `url`, a `username` and a `password`.

 A `name` is optional and is only for a user's informational purposes.
 */
class Space: NSObject {

    /**
     Maximum number of failed uploads per space before the circuit breaker opens.
     */
    static let maxFails = 10

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
     This needs to be tied to an object, otherwise the SessionManager will get
     destroyed during the request and the request will break with error -999.

     See [Getting code=-999 using custom SessionManager](https://github.com/Alamofire/Alamofire/issues/1684)
     */
    lazy var sessionManager: SessionManager = {
        let conf = URLSessionConfiguration.background(withIdentifier:
            "\(Bundle.main.bundleIdentifier ?? "").background")
        conf.sharedContainerIdentifier = Constants.appGroup

        // Fix error "CredStore - performQuery - Error copying matching creds."
        conf.urlCredentialStorage = nil

        conf.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        return SessionManager(configuration: conf)
    }()


    var name: String?
    var url: URL?
    var favIcon: UIImage?
    var username: String?
    var password: String?
    var authorName: String?
    var authorRole: String?
    var authorOther: String?

    // Circuit breaker pattern for uploads
    var tries = 0
    var lastTry: Date?
    var nextTry: Date {
        return lastTry?.addingTimeInterval(10 * 60) ?? Date(timeIntervalSince1970: 0)
    }
    var uploadAllowed: Bool {
        return tries < Space.maxFails || nextTry.compare(Date()) == .orderedAscending
    }

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
        id = decoder.decodeObject(forKey: "id") as? String ?? UUID().uuidString
        name = decoder.decodeObject(forKey: "name") as? String
        url = decoder.decodeObject(forKey: "url") as? URL
        favIcon = decoder.decodeObject(forKey: "favIcon") as? UIImage
        username = decoder.decodeObject(forKey: "username") as? String
        password = decoder.decodeObject(forKey: "password") as? String
        authorName = decoder.decodeObject(forKey: "authorName") as? String
        authorRole = decoder.decodeObject(forKey: "authorRole") as? String
        authorOther = decoder.decodeObject(forKey: "authorOther") as? String
        tries = decoder.decodeInteger(forKey: "tries")
        lastTry = decoder.decodeObject(forKey: "lastTry") as? Date
    }

    @objc(encodeWithCoder:) func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(url, forKey: "url")
        coder.encode(favIcon, forKey: "favIcon")
        coder.encode(username, forKey: "username")
        coder.encode(password, forKey: "password")
        coder.encode(authorName, forKey: "authorName")
        coder.encode(authorRole, forKey: "authorRole")
        coder.encode(authorOther, forKey: "authorOther")
        coder.encode(tries, forKey: "tries")
        coder.encode(lastTry, forKey: "lastTry")
    }


    // MARK: NSCopying

    @objc(copyWithZone:) func copy(with zone: NSZone? = nil) -> Any {
        return NSKeyedUnarchiver.unarchiveObject(with:
            NSKeyedArchiver.archivedData(withRootObject: self))!
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), url=\(url?.description ?? "nil"), "
            + "favIcon=\(favIcon?.description ?? "nil"), "
            + "username=\(username ?? "nil"), password=\(password ?? "nil"), "
            + "authorName=\(authorName ?? "nil"), authorRole=\(authorRole ?? "nil"), "
            + "authorOther=\(authorOther ?? "nil"), tries=\(tries), lastTry=\(String(describing: lastTry))]"
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
     - parameter error: An optional `Error`, defaults to `nil`.
     - parameter url: The URL the asset was uploaded to, if any. Defaults to `nil`.
    */
    func done(_ uploadId: String, _ error: Error? = nil, _ url: URL? = nil) {
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
}

//
//  Formatters.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class Formatters: NSObject {

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        return formatter
    }()

    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"

        return formatter
    }()

    static let friendlyTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter
    }()

    static let integer = NumberFormatter()

    /**
     Formats an integer properly localized.
    */
    static func format(_ value: Int) -> String {
        return integer.string(from: NSNumber(value: value)) ?? "-1"
    }

    /**
     Formats a timestamp in a friendly format like
     `Today at 1:07 PM' or 'Jan 1, 2019 10:00 AM'.
    */
    static func format(_ value: Date) -> String {
        return friendlyTimestamp.string(from: value)
    }

    /**
     A formatter for URLs usable in Eureka forms.

     Makes it easy to connect Nextcloud servers without having to know all the
     details. Users just needs to provide the host name.
    */
    class URLFormatter: Formatter {

        override func string(for obj: Any?) -> String? {
            return Formatters.URLFormatter.fix(url: obj as? URL)?.absoluteString
        }

        override func getObjectValue(
            _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String,
            errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
            
            if let url = URL(string: string) {
                obj?.pointee = url as AnyObject

                return true
            }

            return false
        }

        /**
         Fixes a given URL, if any given:

         - Set scheme to "https", if none set, yet.
         - Set path as host, if no host; set path empty, if done so.
         - Set path to "/remote.php/webdav/" (Nextcloud default WebDAV endpoint),
           if path is empty or root "/".

         - parameter url: The URL to fix.
         - parameter baseOnly: if true, removes user, password, query and fragment components and sets path to "/".
         - returns: A fixed copy of the input URL.
        */
        class func fix(url: URL?, baseOnly: Bool = false) -> URL? {
            if let url = url,
                var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true) {

                if urlc.scheme?.isEmpty ?? true {
                    urlc.scheme = "https"
                }

                if urlc.host?.isEmpty ?? true {
                    urlc.host = urlc.path
                    urlc.path = ""
                }

                if urlc.path.isEmpty || urlc.path == "/" {
                    urlc.path = "/remote.php/webdav/"
                }

                if baseOnly {
                    urlc.user = nil
                    urlc.password = nil
                    urlc.path = "/"
                    urlc.query = nil
                    urlc.fragment = nil
                }

                return urlc.url
            }

            return nil
        }
    }
}

//
//  Formatters.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import Contacts

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

    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true

        return formatter
    }()

    static let bytes = ByteCountFormatter()

    static let address = CNPostalAddressFormatter()

    static let location: TTTLocationFormatter = {
        let formatter = TTTLocationFormatter()
        formatter.coordinateStyle = .degreesMinutesSecondsFormat

        return formatter
    }()

    /**
     Formats an integer properly localized.
    */
    static func format(_ value: Int?) -> String {
        return format(value == nil ? Int64.min : Int64(value!))
    }

    /**
     Formats an integer properly localized.
     */
    static func format(_ value: UInt?) -> String {
        return format(value == nil ? Int64.min : Int64(value!))
    }

    /**
     Formats an integer properly localized.
     */
    static func format(_ value: Int64?) -> String {
        return integer.string(from: NSNumber(value: value ?? Int64.min)) ?? String(Int64.min)
    }

    /**
     Formats an integer properly localized as a human readable byte count.
     */
    static func formatByteCount(_ value: Int64?) -> String {
        return bytes.string(fromByteCount: value ?? 0)
    }

    /**
     Formats a timestamp in a friendly format like
     `Today at 1:07 PM' or 'Jan 1, 2019 10:00 AM'.
    */
    static func format(_ value: Date) -> String {
        return friendlyTimestamp.string(from: value)
    }

    /**
     Formats a duration either as `MM:SS` or `H:MM:SS` (if duration is > 1 hour).
     */
    static func format(_ value: TimeInterval) -> String {
        let seconds = lround(value)
        let minute = seconds / 60
        let second = seconds % 60

        if minute > 59 {
            return String(format: "%d:%02d:%02d", minute / 60, minute % 60, second)
        }
        else {
            return String(format: "%d:%02d", minute, second)
        }
    }

    /**
     A formatter for URLs usable in Eureka forms.

     Makes it easy to connect Nextcloud servers without having to know all the
     details. Users just need to provide the host name.
    */
    class URLFormatter: Formatter {

        override func string(for obj: Any?) -> String? {
            return Formatters.URLFormatter.fix(url: obj as? URL)?.absoluteString
        }

        override func getObjectValue(
            _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String,
            errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
        {
            if let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                obj?.pointee = url as AnyObject

                return true
            }

            return false
        }

        /**
         Fixes a given URL, if any given:

         - Set scheme to "https", if not already set so.
         - Set path as host, if no host; set path empty, if done so.
         - Set path to "/remote.php/webdav/" (Nextcloud default WebDAV endpoint),
           if path is empty or root "/".

         - parameter url: The URL to fix.
         - parameter baseOnly: if true, removes user, password, query and fragment components and sets path to "/".
         - returns: A fixed copy of the input URL.
        */
        class func fix(url: URL?, baseOnly: Bool = false) -> URL? {
            if let url = url,
                var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true)
            {
                // We're currently not allowing non-encrypted communication
                // (Default iOS App-Transport-Security!), so we shouldn't allow
                // anything else then HTTPS.
                if urlc.scheme != "https" {
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

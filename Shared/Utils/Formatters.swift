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
}

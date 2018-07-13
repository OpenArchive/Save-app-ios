//
//  StringUtils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class StringUtils {

    private static let symbols = "abcdefghijklmnopqrstuvwxyz0123456789"

    /**
     Creates a random string of given length containing lower case letters and numbers.

     - parameter length: the length of the generated string.
     - returns: a string of given length with random characters from [a-z0-9].
    */
    class func random(_ length: Int) -> String {
        let len = UInt32(symbols.count)

        var random = ""

        for _ in 0 ..< length {
            random += String(symbols[symbols.index(symbols.startIndex, offsetBy: Int(arc4random_uniform(len)))])
        }

        return random
    }

    /**
     Replaces all characters in a string, which don't conform to this regex: [A-Za-z0-9]

     - parameter name: The original string
     - returns: a cleaned string usable as slug, e.g. in URLs
    */
    class func slug(_ name: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "[^A-Za-z0-9]", options: []) {
            return regex.stringByReplacingMatches(in: name, options: [],
                                                  range: NSMakeRange(0, name.count),
                                                  withTemplate: "-")
        }

        return name
    }
}

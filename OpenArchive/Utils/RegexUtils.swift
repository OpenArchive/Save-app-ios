//
//  RegexUtils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 04.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class RegexUtils {

    /**
     Checks, if a given `pattern` is found in a `haystack` using case insensitive regular expressions.

     - parameter haystack: The string to search in.
     - parameter pattern: The regular expression to use for search.
     - returns: `true`, if regex compiles and found at least once, `false` otherwise.
    */
    class func containsCi(_ haystack: String, pattern: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: haystack, options: [],
                                        range: NSRange(location: 0, length: haystack.count))

            return matches.count > 0
        }

        return false
    }
}

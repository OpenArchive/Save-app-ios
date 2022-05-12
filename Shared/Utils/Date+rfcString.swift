//
//  FileProviderExtensions.swift
//  FileProvider
//
//  Created by Amir Abbas on 12/27/1395 AP.
//

import Foundation

extension Date {
    /// Date formats used commonly in internet messaging defined by various RFCs.
    public enum RFCStandards: String {
        /// Obsolete (2-digit year) date format defined by RFC 822 for http.
        case rfc822 = "EEE',' dd' 'MMM' 'yy HH':'mm':'ss z"
        /// Obsolete (2-digit year) date format defined by RFC 850 for usenet.
        case rfc850 = "EEEE',' dd'-'MMM'-'yy HH':'mm':'ss z"
        /// Date format defined by RFC 1123 for http.
        case rfc1123 = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss z"
        /// Date format defined by RFC 3339, as a profile of ISO 8601.
        case rfc3339 = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"
        /// Date format defined RFC 3339 as rare case with milliseconds.
        case rfc3339Extended = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSZZZZZ"
        /// Date string returned by asctime() function.
        case asctime = "EEE MMM d HH':'mm':'ss yyyy"

        //  Defining a http alias allows changing default time format if a new RFC becomes standard.
        /// Equivalent to and defined by RFC 1123.
        public static let http = RFCStandards.rfc1123
        /// Equivalent to and defined by RFC 850.
        public static let usenet = RFCStandards.rfc850

        /* re. [RFC7231 section-7.1.1.1](https://tools.ietf.org/html/rfc7231#section-7.1.1.1)
         "HTTP servers and client MUST accept all three HTTP-date formats" which are IMF-fixdate,
         obsolete RFC 850 format and ANSI C's asctime() format.

         ISO 8601 format is common in JSON and XML fields, defined by RFC 3339 as a timestamp format.
         Though not mandated, we check string against them to allow using Date(rfcString:) in
         wider and more general sitations.

         We use RFC 822 instead of RFC 1123 to convert from string because NSDateFormatter can parse
         both 2-digit and 4-digit year correctly when `dateFormat` year is 2-digit.

         These values are sorted by frequency.
         */
        fileprivate static let parsingCases: [RFCStandards] = [.rfc822, .rfc850, .asctime, .rfc3339, .rfc3339Extended]
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    private static let utcTimezone = TimeZone(identifier: "UTC")

    /// Checks date string against various RFC standards and returns `Date`.
    public init?(rfcString: String) {
        let dateFor: DateFormatter = DateFormatter()
        dateFor.locale = Date.posixLocale

        for standard in RFCStandards.parsingCases {
            dateFor.dateFormat = standard.rawValue
            if let date = dateFor.date(from: rfcString) {
                self = date
                return
            }
        }

        return nil
    }

    /// Formats date according to RFCs standard.
    /// - Note: local and timezone paramters should be nil for `.http` standard
    internal func format(with standard: RFCStandards, locale: Locale? = nil, timeZone: TimeZone? = nil) -> String {
        let fm = DateFormatter()
        fm.dateFormat = standard.rawValue
        fm.timeZone = timeZone ?? Date.utcTimezone
        fm.locale = locale ?? Date.posixLocale
        return fm.string(from: self)
    }
}

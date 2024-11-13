//
//  Constants.swift
//  Save
//
//  Created by navoda on 2024-11-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
struct TimeIntervalConstants {
    static let hoursInDay: Double = 24.0
    static let minutuesInHour: Double = 60.0
    static let secondsInDay: TimeInterval = hoursInDay * minutuesInHour * secondsInMinute
    static let secondsInHour: TimeInterval = minutuesInHour * secondsInMinute
    static let secondsInMinute: TimeInterval = 60.0
    static let secondsInSecond: TimeInterval = 1.0
}

struct GeneralConstants {
    static let percentBase: CGFloat = 100.0
    static let maxSpelledOutValue: Int = 9
    static let minSpelledOutValue: Int = 1
    static let percentRoundedTo:Int = 2
}

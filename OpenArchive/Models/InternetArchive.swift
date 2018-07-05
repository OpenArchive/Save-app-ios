//
//  InternetArchive.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class InternetArchive {

    private static let ACCESS_KEY = "ACCESS_KEY"
    private static let SECRET_KEY = "SECRET_KEY"

    public static var accessKey: String? {
        get {
            return UserDefaults.standard.string(forKey: InternetArchive.ACCESS_KEY)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: InternetArchive.ACCESS_KEY)
        }
    }

    public static var secretKey: String? {
        get {
            return UserDefaults.standard.string(forKey: InternetArchive.SECRET_KEY)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: InternetArchive.SECRET_KEY)
        }
    }
}

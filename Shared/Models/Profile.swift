//
//  Profile.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 16.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import UIImage_Resize

class Profile: NSObject {

    private static let AVATAR = "PROFILE_AVATAR"
    private static let ALIAS = "PROFILE_ALIAS"
    private static let ROLE = "PROFILE_ROLE"

    /**
     The default avatar image to show, when there's no user-defined one.
    */
    static var defaultAvatar = UIImage(named: "avatar-empty")

    /**
     Cache for decoded avatar. Decoding it all the time costs a lot of time!
    */
    private static var _avatar: UIImage?

    static var avatar: UIImage? {
        get {
            if _avatar != nil {
                return _avatar
            }

            if let data = UserDefaults(suiteName: Constants.suiteName)?
                .data(forKey: AVATAR) {

                _avatar = UIImage(data: data)

                return _avatar
            }

            return nil
        }
        set {
            _avatar = newValue?.resizedImageToFit(in: CGSize(width: 320, height: 320),
                                                  scaleIfSmaller: false)

            UserDefaults(suiteName: Constants.suiteName)?
                .set(_avatar?.jpegData(compressionQuality: 0.5), forKey: AVATAR)
        }
    }

    static var alias: String? {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?
                .string(forKey: ALIAS)
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?
                .set(newValue, forKey: ALIAS)
        }
    }

    static var role: String? {
        get {
            return UserDefaults(suiteName: Constants.suiteName)?
                .string(forKey: ROLE)
        }
        set {
            UserDefaults(suiteName: Constants.suiteName)?
                .set(newValue, forKey: ROLE)
        }
    }
}

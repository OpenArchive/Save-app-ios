//
//  IaInfoAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 21.08.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

/**
 A special alert which informs the user about the Internet Archive support.
 */
class IaInfoAlert: InfoAlert {

    override class var image: UIImage? {
        return UIImage(named: "InternetArchiveLogo")
    }

    override class var title: String {
        return "Internet Archive".localize()
    }

    override class var message: String {
        return "You will need to log in to or create an Internet Archive account in order to send and preserve Save media at the Internet Archive.".localize()
    }

    override class var wasAlreadyShown: Bool {
        get {
            return Settings.iaShownFirstTime
        }
        set {
            Settings.iaShownFirstTime = newValue
        }
    }
}

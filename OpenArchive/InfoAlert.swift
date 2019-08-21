//
//  InfoAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 21.08.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SDCAlertView

/**
 A special alert which gives the user a hint about a special feature.
 */
class InfoAlert {

    /**
     An illustrative image shown above the title, if not nil.
    */
    class var image: UIImage? {
        return nil
    }

    /**
     The color with which the illustrative image gets tinted. If set, image
     will be used as template and tinted, else as-is.
    */
    class var tintColor: UIColor? {
        return nil
    }

    /**
     A title for the alert. Defaults to empty and will not be shown, if left as such.
    */
    class var title: String {
        return ""
    }

    /**
     The main message to display.
    */
    class var message: String {
        return ""
    }

    /**
     Shall be true, if InfoAlert was already shown once and shouldn't be shown
     again.

     Will be set to true after the alert completed.
    */
    class var wasAlreadyShown: Bool {
        get {
            return true
        }
        set {
            // Only implemented in subclass.
        }
    }

    /**
     Shows the special info alert, if never shown before.

     - parameter viewController: The viewController to present on. Can be nil,
        in which case the top view controller will be taken.
    */
    class func presentIfNeeded(_ viewController: UIViewController? = nil) {
        if wasAlreadyShown {
            return
        }

        let illustration: UIImageView?

        if let image = image {
            if let tintColor = tintColor {
                illustration = UIImageView(image: image.withRenderingMode(.alwaysTemplate))
                illustration?.tintColor = tintColor
            }
            else {
                illustration = UIImageView(image: image)
            }

            illustration?.translatesAutoresizingMaskIntoConstraints = false
        }
        else {
            illustration = nil
        }

        let title: UILabel?

        if !self.title.isEmpty {
            title = UILabel()
            title?.translatesAutoresizingMaskIntoConstraints = false
            title?.text = self.title
            title?.font = UIFont.boldSystemFont(ofSize: 17)
            title?.textAlignment = .center
            title?.adjustsFontSizeToFitWidth = true
        }
        else {
            title = nil
        }

        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.text = self.message
        message.font = UIFont.systemFont(ofSize: 13)
        message.textAlignment = .center
        message.numberOfLines = 0

        let alert = AlertController(title: nil, message: nil)

        let cv = alert.contentView

        if let illustration = illustration {
            cv.addSubview(illustration)
        }

        if let title = title {
            cv.addSubview(title)
        }

        cv.addSubview(message)

        illustration?.topAnchor.constraint(equalTo: cv.topAnchor, constant: -16).isActive = true
        illustration?.widthAnchor.constraint(equalToConstant: 24).isActive = true
        illustration?.heightAnchor.constraint(equalToConstant: 24).isActive = true
        illustration?.centerXAnchor.constraint(equalTo: cv.centerXAnchor).isActive = true

        title?.topAnchor.constraint(equalTo: illustration?.bottomAnchor ?? cv.topAnchor, constant: 16).isActive = true
        title?.leftAnchor.constraint(equalTo: cv.leftAnchor).isActive = true
        title?.rightAnchor.constraint(equalTo: cv.rightAnchor).isActive = true

        message.topAnchor.constraint(equalTo: title?.bottomAnchor ?? illustration?.bottomAnchor ?? cv.topAnchor, constant: 8).isActive = true
        message.leftAnchor.constraint(equalTo: cv.leftAnchor).isActive = true
        message.rightAnchor.constraint(equalTo: cv.rightAnchor).isActive = true
        message.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16).isActive = true


        alert.addAction(AlertAction(title: "Got it".localize(), style: .normal))

        let completion = {
            wasAlreadyShown = true
        }

        if let vc = viewController {
            vc.present(alert, animated: true, completion: completion)
        }
        else {
            alert.present(animated: true, completion: completion)
        }
    }
}

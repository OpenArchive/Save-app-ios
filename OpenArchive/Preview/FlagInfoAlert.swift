//
//  FlagInfoAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SDCAlertView

/**
 A special alert which informs the user about the flag feature.
 */
class FlagInfoAlert {

    /**
     Shows the special flag-info alert, if never shown before.

     - parameter viewController: The viewController to present on. Can be nil,
        in which case the top view controller will be taken.
    */
    class func presentIfNeeded(_ viewController: UIViewController? = nil) {
        if Settings.firstFlaggedDone {
            return
        }

        let flag = UIImageView(image: UIImage(named: "ic_flag")?.withRenderingMode(.alwaysTemplate))
        flag.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Flag Significant Content".localize()
        title.font = UIFont.boldSystemFont(ofSize: 17)
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true

        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.text = "When you flag an item, it receives a special tag in its metadata.".localize()
        message.font = UIFont.systemFont(ofSize: 13)
        message.textAlignment = .center
        message.numberOfLines = 0

        let alert = AlertController(title: nil, message: nil)

        let cv = alert.contentView
        cv.addSubview(flag)
        cv.addSubview(title)
        cv.addSubview(message)

        flag.topAnchor.constraint(equalTo: cv.topAnchor, constant: -16).isActive = true
        flag.widthAnchor.constraint(equalToConstant: 24).isActive = true
        flag.heightAnchor.constraint(equalToConstant: 24).isActive = true
        flag.centerXAnchor.constraint(equalTo: cv.centerXAnchor).isActive = true

        title.topAnchor.constraint(equalTo: flag.bottomAnchor, constant: 16).isActive = true
        title.leftAnchor.constraint(equalTo: cv.leftAnchor).isActive = true
        title.rightAnchor.constraint(equalTo: cv.rightAnchor).isActive = true

        message.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8).isActive = true
        message.leftAnchor.constraint(equalTo: cv.leftAnchor).isActive = true
        message.rightAnchor.constraint(equalTo: cv.rightAnchor).isActive = true
        message.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16).isActive = true


        alert.addAction(AlertAction(title: "Got it".localize(), style: .normal))

        let completion = {
            Settings.firstFlaggedDone = true
        }

        if let vc = viewController {
            vc.present(alert, animated: true, completion: completion)
        }
        else {
            alert.present(animated: true, completion: completion)
        }
    }
}

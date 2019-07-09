//
//  BatchInfoAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 09.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SDCAlertView

/**
 A special alert which informs the user about the batch edit feature.
 */
class BatchInfoAlert {

    /**
     Shows the special batch edit info alert, if never shown before.

     - parameter viewController: The viewController to present on. Can be nil,
        in which case the top view controller will be taken.
    */
    class func presentIfNeeded(_ viewController: UIViewController? = nil) {
        if Settings.firstBatchEditDone {
            return
        }

        let flag = UIImageView(image: UIImage(named: "ic_compose")?.withRenderingMode(.alwaysTemplate))
        flag.tintColor = UIColor.warning
        flag.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Edit Multiple Items".localize()
        title.font = UIFont.boldSystemFont(ofSize: 17)
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true

        let message = UILabel()
        message.translatesAutoresizingMaskIntoConstraints = false
        message.text = "To edit multiple items, press and hold each.".localize()
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
            Settings.firstBatchEditDone = true
        }

        if let vc = viewController {
            vc.present(alert, animated: true, completion: completion)
        }
        else {
            alert.present(animated: true, completion: completion)
        }
    }
}

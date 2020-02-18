//
//  UIViewController+Utils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.02.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit

extension UIViewController {

    public var top: UIViewController {
        if let vc = subViewController {
            return vc.top
        }

        return self
    }

    public var subViewController: UIViewController? {
        if let vc = self as? UINavigationController {
            return vc.topViewController
        }

        if let vc = self as? UISplitViewController {
            return vc.viewControllers.last
        }

        if let vc = self as? UITabBarController {
            return vc.selectedViewController
        }

        if let vc = presentedViewController {
            return vc
        }

        return nil
    }
}

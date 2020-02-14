//
//  UIViewController+top.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.02.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit

extension UIViewController {

    public var top: UIViewController? {
        if let navC = self as? UINavigationController {
            return navC.topViewController?.top
        }

        if let splitC = self as? UISplitViewController {
            return splitC.viewControllers.last?.top
        }

        if let tabC = self as? UITabBarController {
            return tabC.selectedViewController?.top
        }

        if let pvc = presentedViewController {
            return pvc.top
        }

        return self
    }
}

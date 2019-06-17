//
//  UIStoryboard+main.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 21.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

extension UIStoryboard {

    class var main: UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle(for: MainViewController.self))
    }

    func instantiate<T>(_ class: T.Type) -> T {
        return instantiateViewController(withIdentifier: String(describing: `class`)) as! T
    }
}

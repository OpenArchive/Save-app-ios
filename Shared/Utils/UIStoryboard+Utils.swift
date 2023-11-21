//
//  UIStoryboard+Utils.swift
//  Save
//
//  Created by Benjamin Erhart on 21.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

extension UIStoryboard {

    static let main = UIStoryboard(name: "Main", bundle: Bundle(for: MainViewController.self))

    func instantiate<T: UIViewController>(_ class: T.Type) -> T {
        instantiateViewController(withIdentifier: String(describing: `class`)) as! T
    }
}

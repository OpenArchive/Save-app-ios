//
//  UITableView+separatorView.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

extension UITableView {
    
    var separatorView: UIView {
        let view = UIView()

        let insets = separatorInset
        let width = bounds.width - insets.left - insets.right
        let frame = CGRect(x: insets.left, y: -0.5, width: width, height: 0.5)

        let separator = CALayer()
        separator.frame = frame
        separator.backgroundColor = separatorColor?.cgColor
        view.layer.addSublayer(separator)

        return view
    }
}

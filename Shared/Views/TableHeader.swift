//
//  Header.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TableHeader: UITableViewHeaderFooterView {

    class var reuseId: String {
        return String(describing: self)
    }

    var text: String? {
        get {
            return textLabel?.text
        }
        set {
            textLabel?.text = newValue?.localizedUppercase
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Of course it would be way better to do that in #init or even in #text,
        // but iOS has other ideas about font sizes and background color.
        textLabel?.textColor = tintColor
        textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        backgroundView?.backgroundColor = UIColor.white
    }
}

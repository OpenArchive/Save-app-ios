//
//  TintedButton.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Flag: UIImageView {

    open var isSelected: Bool {
        get {
            tintColor == .warning
        }
        set {
            if newValue {
                image = .init(systemName: "flag.fill")
                tintColor = .warning
            }
            else {
                image = .init(systemName: "flag")
                tintColor = .white
            }
        }
    }
}

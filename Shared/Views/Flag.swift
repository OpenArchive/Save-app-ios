//
//  TintedButton.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Flag: UIImageView {
    
    var unselectedTintColor: UIColor

    // Initializer to allow a custom unselected color
    init(unselectedTintColor: UIColor = .label) {
        self.unselectedTintColor = unselectedTintColor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.unselectedTintColor = .label
        super.init(coder: coder)
    }

    open var isSelected: Bool {
        get {
            tintColor == .warning
        }
        set {
            if newValue {
                image = .init(systemName: "flag.fill")
                tintColor = .warning
            } else {
                image = .init(systemName: "flag")
                tintColor = unselectedTintColor
            }
        }
    }
}

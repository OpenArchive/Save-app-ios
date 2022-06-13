//
//  Header.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class TableHeader: UITableViewHeaderFooterView {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

    class var height: CGFloat {
        return 54
    }

    static let reducedHeight: CGFloat = 24

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    @IBOutlet weak var label: UILabel! {
        didSet {
            label.font = label.font.bold()
        }
    }

    override var textLabel: UILabel? {
        get {
            return label
        }
        set {
            label = newValue
        }
    }

    private func setup() {
        // Fixes iOS 15, which will draw a background in tint color, otherwise.
        backgroundView = UIView(frame: .zero)
    }
}

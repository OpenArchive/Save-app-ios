//
//  InfoBox.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class InfoBox: UIView {

    class func instantiate(_ icon: String? = nil, _ superview: UIView? = nil) -> InfoBox? {
        let info = UINib(nibName: String(describing: self), bundle: Bundle(for: self))
            .instantiate(withOwner: nil, options: nil).first as? InfoBox

        if let info = info {
            if let icon = icon {
                info.icon.image = UIImage(named: icon)?.withRenderingMode(.alwaysTemplate)
            }

            superview?.addSubview(info)
        }

        return info
    }

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var label: UILabel!

    private var zeroHeight: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        translatesAutoresizingMaskIntoConstraints = false
    }

    func addConstraints(_ superview: UIView, top: UIView? = nil, bottom: UIView? = nil) {
        leftAnchor.constraint(equalTo: superview.leftAnchor).isActive = true
        rightAnchor.constraint(equalTo: superview.rightAnchor).isActive = true
        topAnchor.constraint(equalTo: top == nil ? superview.topAnchor : top!.bottomAnchor).isActive = true
        bottomAnchor.constraint(equalTo: bottom == nil ? superview.bottomAnchor : bottom!.topAnchor).isActive = true
    }

    func set(_ text: String?) {
        label.text = text

        if zeroHeight == nil {
            zeroHeight = heightAnchor.constraint(equalToConstant: 0)
        }

        isHidden = text?.isEmpty ?? true

        zeroHeight?.isActive = isHidden
    }
}

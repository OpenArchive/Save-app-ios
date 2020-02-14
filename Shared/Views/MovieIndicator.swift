//
//  MovieIndicator.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.09.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MovieIndicator: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    public func set(duration: TimeInterval?) {
        if let duration = duration {
            durationLb.text = Formatters.format(duration)
            durationLb.isHidden = false
        }
        else {
            durationLb.isHidden = true
        }
    }

    public func inset(_ value: CGFloat) {
        leadingInset.constant = value
        topInsetIcon.constant = value
        topInsetDuration.constant = value
        trailingInset.constant = -value
        bottomInsetIcon.constant = -value
        bottomInsetDuration.constant = -value
    }

    private var durationLb: UILabel!
    private var leadingInset: NSLayoutConstraint!
    private var topInsetIcon: NSLayoutConstraint!
    private var topInsetDuration: NSLayoutConstraint!
    private var bottomInsetIcon: NSLayoutConstraint!
    private var bottomInsetDuration: NSLayoutConstraint!
    private var trailingInset: NSLayoutConstraint!

    private func setup() {
        let icon = UIImageView(image: UIImage(named: "video"))
        icon.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)

        leadingInset = icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2)
        leadingInset.isActive = true
        topInsetIcon = icon.topAnchor.constraint(equalTo: topAnchor)
        topInsetIcon.isActive = true
        bottomInsetIcon = icon.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomInsetIcon.isActive = true
        icon.heightAnchor.constraint(equalTo: icon.widthAnchor, multiplier: 1).isActive = true

        durationLb = UILabel()
        durationLb.textAlignment = .right
        if #available(iOS 13.0, *) {
            durationLb.textColor = .systemBackground
        }
        else {
            durationLb.textColor = .white
        }
        durationLb.font = .systemFont(ofSize: 12)
        durationLb.translatesAutoresizingMaskIntoConstraints = false
        durationLb.isHidden = true

        addSubview(durationLb)

        topInsetDuration = durationLb.topAnchor.constraint(equalTo: topAnchor)
        topInsetDuration.isActive = true
        bottomInsetDuration = durationLb.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomInsetDuration.isActive = true
        trailingInset = durationLb.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)
        trailingInset.isActive = true
    }
}

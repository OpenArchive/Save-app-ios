//
//  MultilineTitle.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MultilineTitle: UIView {

    let title: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textAlignment = .center

        return label
    }()

    let subtitle: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 10)
        label.textAlignment = .center

        return label
    }()


    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(title)
        title.topAnchor.constraint(equalTo: topAnchor).isActive = true
        title.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        title.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        title.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5).isActive = true

        addSubview(subtitle)
        subtitle.topAnchor.constraint(equalTo: title.bottomAnchor).isActive = true
        subtitle.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        subtitle.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        subtitle.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
}

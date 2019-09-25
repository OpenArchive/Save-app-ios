//
//  ProjectTab.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.09.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class ProjectTab: UIButton {

    var project: Project

    var leadingConstraint: NSLayoutConstraint?
    var trailingConstraintToSuperview: NSLayoutConstraint?


    init(_ project: Project) {
        self.project = project

        super.init(frame: .zero)

        setup()
    }

    required init?(coder: NSCoder) {
        project = coder.decodeObject(forKey: "project") as! Project

        super.init(coder: coder)

        setup()
    }

    override func encode(with coder: NSCoder) {
        coder.encode(project, forKey: "project")

        super.encode(with: coder)
    }

    func addToSuperview(_ superview: UIView, leadingConstraintTo leadingSibling: UIView? = nil) {
        removeFromSuperview()
        superview.addSubview(self)

        centerYAnchor.constraint(equalTo: superview.centerYAnchor).isActive = true

        setLeadingConstraint(leadingSibling)

        trailingConstraintToSuperview = trailingAnchor.constraint(equalTo: superview.trailingAnchor)
    }

    func setLeadingConstraint(_ leadingSibling: UIView? = nil) {
        leadingConstraint?.isActive = false

        if let leadingSibling = leadingSibling {
            leadingConstraint = leadingAnchor.constraint(equalTo: leadingSibling.trailingAnchor, constant: 8)
        }
        else if let superview = superview {
            leadingConstraint = leadingAnchor.constraint(equalTo: superview.leadingAnchor)
        }

        leadingConstraint?.isActive = true
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)

        setTitleColor(.gray, for: .normal)
        setTitleColor(.black, for: .selected)
    }

    override func layoutSubviews() {
        setTitle(project.name, for: .normal)

        super.layoutSubviews()
    }
}

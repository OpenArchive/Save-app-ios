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

    var trailingConstraintToSuperview: NSLayoutConstraint?

    override var isSelected: Bool {
        didSet {
            if isSelected {
                addSubview(indicator)

                indicator.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
                indicator.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
                indicator.topAnchor.constraint(equalTo: bottomAnchor, constant: 4).isActive = true
                indicator.heightAnchor.constraint(equalToConstant: 2).isActive = true
            }
            else {
                indicator.removeFromSuperview()
            }
        }
    }

    private var leadingConstraint: NSLayoutConstraint?

    private lazy var indicator: UIView = {
        let indicator = UIView(frame: .zero)
        indicator.backgroundColor = .accent
        indicator.translatesAutoresizingMaskIntoConstraints = false

        return indicator
    }()

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
            leadingConstraint = leadingAnchor.constraint(equalTo: leadingSibling.trailingAnchor, constant: 16)
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

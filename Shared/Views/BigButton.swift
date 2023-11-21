//
//  BigButton.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class BigButton: UIView {

    @discardableResult
    class func create(icon: UIImage? = nil, title: String, subtitle: String? = nil,
                      target: Any? = nil, action: Selector? = nil, container: UIView,
                      above: UIView, equalHeight: Bool = false) -> BigButton
    {
        let button = BigButton()

        button.icon = icon
        button.title = title
        button.subtitle = subtitle

        if let target = target, let action = action {
            button.addTarget(target, action: action)
        }

        container.addSubview(button)
        button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16).isActive = true
        button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16).isActive = true
        button.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 16).isActive = true

        if equalHeight {
            button.heightAnchor.constraint(equalTo: above.heightAnchor, constant: 0).isActive = true
        }

        return button
    }

    // MARK: Public Properties

    var icon: UIImage? {
        get {
            leadIv.image
        }
        set {
            if newValue == nil && leadIv.image != nil {
                for constraint in leadIv.constraints {
                    switch constraint.firstAttribute {
                    case .leading, .centerY, .trailing:
                        constraint.isActive = false

                    default:
                        break
                    }
                }

                leadIv.removeFromSuperview()

                titleLeadingConstraint?.isActive = true
            }
            else if newValue != nil && leadIv.image == nil {
                addSubview(leadIv)

                leadIv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
                leadIv.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

                titleLeadingConstraint?.isActive = false

                titleLb.leadingAnchor.constraint(equalTo: leadIv.trailingAnchor, constant: 8).isActive = true
            }

            leadIv.image = newValue
        }
    }

    var title: String? {
        get {
            titleLb.text
        }
        set {
            titleLb.text = newValue
        }
    }

    var subtitle: String? {
        get {
            subtitleLb.text
        }
        set {
            titleLb.constraints.first(where: { $0.firstAttribute == .bottom })?.isActive = false

            if newValue?.isEmpty ?? true && !(subtitleLb.text?.isEmpty ?? true) {
                subtitleLb.removeFromSuperview()

                titleBottomConstraint?.isActive = true
            }
            else if !(newValue?.isEmpty ?? true) && subtitleLb.text?.isEmpty ?? true {
                addSubview(subtitleLb)

                titleBottomConstraint?.isActive = false

                subtitleLb.leadingAnchor.constraint(equalTo: titleLb.leadingAnchor).isActive = true
                subtitleLb.trailingAnchor.constraint(equalTo: titleLb.trailingAnchor).isActive = true
                subtitleLb.topAnchor.constraint(equalTo: titleLb.bottomAnchor, constant: 4).isActive = true
                subtitleLb.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24).isActive = true
            }

            subtitleLb.text = newValue
        }
    }

    override class var requiresConstraintBasedLayout: Bool {
        true
    }


    // MARK: Private Properties

    private lazy var leadIv: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false

        view.widthAnchor.constraint(equalToConstant: 24).isActive = true
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true

        return view
    }()

    private lazy var titleLb: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .preferredFont(forTextStyle: .title2)
        view.numberOfLines = 0

        return view
    }()

    private var titleLeadingConstraint: NSLayoutConstraint?
    private var titleBottomConstraint: NSLayoutConstraint?

    private lazy var subtitleLb: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .preferredFont(forTextStyle: .footnote)
        view.textColor = .secondaryLabel
        view.numberOfLines = 0

        return view
    }()

    private lazy var arrowIv: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = UIImage(systemName: "arrow.right")?.withRenderingMode(.alwaysTemplate)
        view.tintColor = .accent

        view.widthAnchor.constraint(equalToConstant: 24).isActive = true
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true

        return view
    }()


    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }


    // MARK: Public Methods

    func addTarget(_ target: Any?, action: Selector?) {
        let gr = UITapGestureRecognizer(target: target, action: action)

        addGestureRecognizer(gr)
        isUserInteractionEnabled = true
    }

    func removeTargets() {
        isUserInteractionEnabled = false

        for gr in gestureRecognizers ?? [] {
            removeGestureRecognizer(gr)
        }
    }


    // MARK: Private Methods

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        borderColor = .label
        borderWidth = 1
        cornerRadius = 8

        backgroundColor = .systemBackground

        addSubview(arrowIv)
        arrowIv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
        arrowIv.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        addSubview(titleLb)
        titleLeadingConstraint = titleLb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        titleLeadingConstraint?.isActive = true

        titleLb.trailingAnchor.constraint(equalTo: arrowIv.leadingAnchor, constant: -8).isActive = true
        titleLb.topAnchor.constraint(equalTo: topAnchor, constant: 24).isActive = true

        titleBottomConstraint = titleLb.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        titleBottomConstraint?.isActive = true
    }
}

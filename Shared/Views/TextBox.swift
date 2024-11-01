//
//  TextBox.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

protocol TextBoxDelegate {

    func textBox(didUpdate textBox: TextBox)

    func textBox(shouldReturn textBox: TextBox) -> Bool
}

@IBDesignable
class TextBox: UIView, UITextFieldDelegate {

    enum Status {
        case good
        case bad
        case unknown
        case reveal
    }

    @IBInspectable
    var placeholder: String? {
        get {
            textField.placeholder
        }
        set {
            textField.placeholder = newValue
        }
    }

    @IBInspectable
    var text: String? {
        get {
            textField.text
        }
        set {
            textField.text = newValue
        }
    }

    private var shallBeSecureTextEntry = false

    @IBInspectable
    var isSecureTextEntry: Bool {
        get {
            textField.isSecureTextEntry
        }
        set {
            textField.isSecureTextEntry = newValue
            shallBeSecureTextEntry = newValue
        }
    }

    @IBInspectable
    var isEnabled: Bool {
        get {
            textField.isEnabled
        }
        set {
            textField.isEnabled = newValue
        }
    }

    @IBInspectable
    var autocorrectionType: UITextAutocorrectionType {
        get {
            textField.autocorrectionType
        }
        set {
            textField.autocorrectionType = newValue
        }
    }

    @IBInspectable
    var autocapitalizationType: UITextAutocapitalizationType {
        get {
            textField.autocapitalizationType
        }
        set {
            textField.autocapitalizationType = newValue
        }
    }

    var status: Status = .unknown {
        didSet {
            switch status {
            case .good:
                borderColor = .accent
                statusIv.isHidden = false
                statusIvWidth?.constant = 16
                statusIvTrailing?.constant = -8
                statusIv.tintColor = .accent
                statusIv.image = .init(systemName: "checkmark")

            case .bad:
                borderColor = .systemRed
                statusIv.isHidden = false
                statusIvWidth?.constant = 16
                statusIvTrailing?.constant = -8
                statusIv.tintColor = .systemRed
                statusIv.image = .init(systemName: "exclamationmark.circle")

            case .unknown:
                borderColor = .secondaryLabel
                statusIv.isHidden = true
                statusIvWidth?.constant = 0
                statusIvTrailing?.constant = 0

            case .reveal:
                borderColor = .secondaryLabel
                statusIv.isHidden = false
                statusIvWidth?.constant = 16
                statusIvTrailing?.constant = -8
                statusIv.tintColor = .systemGray
                statusIv.image = .init(systemName: isSecureTextEntry ? "eye.slash" : "eye")
            }
        }
    }

    var delegate: TextBoxDelegate?

    override class var requiresConstraintBasedLayout: Bool {
        true
    }


    // MARK: Private Properties

    lazy var textField: UITextField = {
        let view = UITextField()
        view.returnKeyType = .next
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clearButtonMode = .whileEditing
        view.delegate = self

        return view
    }()

    private lazy var statusIv: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true

        statusIvWidth = view.widthAnchor.constraint(equalToConstant: 0)
        statusIvWidth?.isActive = true
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true

        return view
    }()

    private var statusIvWidth: NSLayoutConstraint?
    private var statusIvTrailing: NSLayoutConstraint?

    private lazy var revealGr = UITapGestureRecognizer(target: self, action: #selector(reveal))



    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }


    @discardableResult
    override func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }


    // MARK: UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        status = shallBeSecureTextEntry ? .reveal : .unknown

        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        status = shallBeSecureTextEntry ? .reveal : .unknown

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if reason == .committed {
            delegate?.textBox(didUpdate: self)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.textBox(shouldReturn: self) ?? true
    }


    // MARK: Private Methods

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        borderColor = .secondaryLabel
        borderWidth = 1
        cornerRadius = 8

        addSubview(statusIv)
        statusIvTrailing = statusIv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0)
        statusIvTrailing?.isActive = true
        statusIv.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        statusIv.addGestureRecognizer(revealGr)

        addSubview(textField)
        textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8).isActive = true
        textField.trailingAnchor.constraint(equalTo: statusIv.leadingAnchor, constant: -8).isActive = true
        textField.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
    }

    @objc private func reveal() {
        guard status == .reveal else {
            return
        }

        textField.isSecureTextEntry = !isSecureTextEntry
        status = .reveal // Trigger UI update
    }
}

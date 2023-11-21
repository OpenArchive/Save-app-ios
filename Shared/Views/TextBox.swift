//
//  TextBox.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

@IBDesignable
class TextBox: UIView, UITextFieldDelegate {

    enum Status {
        case good
        case bad
        case unknown
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

    var status: Status = .unknown {
        didSet {
            switch status {
            case .good:
                borderColor = .accent
                statusIv.isHidden = false
                statusIv.tintColor = .accent
                statusIv.image = .init(systemName: "checkmark")

            case .bad:
                borderColor = .systemRed
                statusIv.isHidden = false
                statusIv.tintColor = .systemRed
                statusIv.image = .init(systemName: "xmark")

            case .unknown:
                borderColor = .secondaryLabel
                statusIv.isHidden = true
            }
        }
    }

    override class var requiresConstraintBasedLayout: Bool {
        true
    }


    // MARK: Private Properties

    private lazy var textField: UITextField = {
        let view = UITextField()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clearButtonMode = .whileEditing
        view.delegate = self

        return view
    }()

    private lazy var statusIv: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true

        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true

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


    // MARK: UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        status = .unknown

        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        status = .unknown

        return true
    }


    // MARK: Private Methods

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        borderColor = .secondaryLabel
        borderWidth = 1
        cornerRadius = 8

        addSubview(statusIv)
        statusIv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8).isActive = true
        statusIv.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        addSubview(textField)
        textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8).isActive = true
        textField.trailingAnchor.constraint(equalTo: statusIv.leadingAnchor, constant: -8).isActive = true
        textField.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
    }
}

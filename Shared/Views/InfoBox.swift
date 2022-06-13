//
//  InfoBox.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

protocol InfoBoxDelegate {
    func textChanged(_ infoBox: InfoBox, _ text: String)

    func tapped(_ infoBox: InfoBox)
}

class InfoBox: UIView, UITextViewDelegate {

    // MARK: Class

    // Don't store, otherwise font won't be recalculated after size change.
    private class var normalFont: UIFont {
        UIFont.preferredFont(forTextStyle: .caption1)
    }

    // Don't store, otherwise font won't be recalculated after size change.
    private class var placeholderFont: UIFont? {
        UIFont.preferredFont(forTextStyle: .caption1).italic()
    }

    class func instantiate(_ icon: String? = nil, _ superview: UIView? = nil) -> InfoBox? {
        let info = UINib(nibName: String(describing: self), bundle: Bundle(for: self))
            .instantiate(withOwner: nil, options: nil).first as? InfoBox

        if let info = info {
            if let icon = icon {
                info.icon.image = UIImage(named: icon)
            }

            superview?.addSubview(info)
        }

        return info
    }


    // MARK: InfoBox

    var delegate: InfoBoxDelegate?

    var isUsed: Bool = false {
        didSet {
            icon.image = icon.image?.withRenderingMode(isUsed ? .alwaysTemplate : .alwaysOriginal)
        }
    }


    @IBOutlet weak var icon: UIImageView!

    @IBOutlet weak var textView: UITextView! {
        didSet {
            textView.delegate = self
        }
    }

    private lazy var textHeight: NSLayoutConstraint = textView.heightAnchor.constraint(equalToConstant: 0)

    private lazy var zeroHeight: NSLayoutConstraint = heightAnchor.constraint(equalToConstant: 0)

    private var text: String?
    private var placeholder: String?

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

    func set(_ text: String?, with placeholder: String? = nil) {
        self.text = text
        self.placeholder = placeholder

        isUsed = !(text?.isEmpty ?? true)
        let hasPlaceholder = !(placeholder?.isEmpty ?? true)

        let isDefault = !isUsed && hasPlaceholder

        textView.text = isUsed ? text : (textView.isFirstResponder ? nil : placeholder)
        textView.font = isDefault && !textView.isFirstResponder
            ? InfoBox.placeholderFont
            : InfoBox.normalFont

        // UITextView does not auto-size as UILabel. So we do that here.
        textHeight.constant = textView.sizeThatFits(CGSize(width: textView.frame.size.width,
                                                           height: CGFloat.greatestFiniteMagnitude)).height
        textHeight.isActive = true

        isHidden = !isUsed && !hasPlaceholder

        zeroHeight.isActive = isHidden
    }


    // MARK: UITextViewDelegate

    /**
     Callback for `textView`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, manually remove placeholder, if any.
     */
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if textView.text == placeholder {
            textView.text = nil
        }

        textView.font = InfoBox.normalFont

        return true
    }

    /**
     Callback for `textView`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, restore placeholder, if nothing entered.

     Update indicator button and delegate changes.
     */
    func textViewDidEndEditing(_ textView: UITextView) {
        text = textView.text

        isUsed = !text!.isEmpty

        if !isUsed {
            textView.text = placeholder
            textView.font = InfoBox.placeholderFont
        }

        delegate?.textChanged(self, text!)
    }

    /**
     Callback for `textView`.

     Hide keyboard, when user hits [enter].
     */
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.endEditing(true)

            return false
        }

        return true
    }
}

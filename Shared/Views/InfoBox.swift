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
        UIFont.montserrat(forTextStyle: .caption1)
    }

    // Don't store, otherwise font won't be recalculated after size change.
    private class var placeholderFont: UIFont? {
        UIFont.montserrat(forTextStyle: .caption1, with: .traitItalic)
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

    @IBOutlet weak var textTopMargin: NSLayoutConstraint?
    @IBOutlet weak var textBottomMargin: NSLayoutConstraint?

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

//    func addConstraints(_ superview: UIView, top: UIView? = nil, bottom: UIView? = nil) {
//        leftAnchor.constraint(equalTo: superview.leftAnchor).isActive = true
//        rightAnchor.constraint(equalTo: superview.rightAnchor).isActive = true
//        topAnchor.constraint(equalTo: top == nil ? superview.topAnchor : top!.topAnchor).isActive = true
//        bottomAnchor.constraint(equalTo: bottom == nil ? superview.bottomAnchor : bottom!.bottomAnchor).isActive = true
//    }
    func addConstraints(_ container: UIView, top: UIView? = nil, bottom: UIView? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
       
        leftAnchor.constraint(equalTo: container.leftAnchor, constant: 0).isActive = true
        rightAnchor.constraint(equalTo: container.rightAnchor, constant: 0).isActive = true
        
        if let topView = top {
            topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 0).isActive = true // Place below the previous view
        } else {
            topAnchor.constraint(equalTo: container.topAnchor, constant: 0).isActive = true // Align to top of `infos`
        }
        
        if let bottomView = bottom {
            bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: 0).isActive = true // Place above bottomView
        }
    }
    func set(_ text: String?, with placeholder: String? = nil,textHeightContraint: CGFloat?) {
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
        if let textHeightContraint = textHeightContraint {
            textHeight.constant = textHeightContraint
        }
        else{
            textHeight.constant = textView.sizeThatFits(CGSize(width: textView.frame.size.width,
                                                               height: CGFloat.greatestFiniteMagnitude)).height
        }
      

        isHidden = !isUsed && !hasPlaceholder

        // Calm the constraints debugger.
        textHeight.isActive = !isHidden
        textTopMargin?.isActive = !isHidden
        textBottomMargin?.isActive = !isHidden
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

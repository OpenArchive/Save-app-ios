//
//  UIFont+Montserrat.swift
//  Save
//
//  Created by Benjamin Erhart on 13.06.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit

extension UIFont {

    static let defaultFontName = "Montserrat-Medium"
    static let boldFontName = "Montserrat-Bold"
    static let italicFontName = "Montserrat-MediumItalic"
    static let boldItalicFontName = "Montserrat-BoldItalic"
    static let blackFontName = "Montserrat-Black"

    static let baseSizes: [UIFont.TextStyle: CGFloat] = [
        .body: 17,
        .callout: 16,
        .caption1: 12,
        .caption2: 11,
        .footnote: 13,
        .headline: 17,
        .subheadline: 15,
        .largeTitle: 34,
        .title1: 28,
        .title2: 22,
        .title3: 20,
    ]

    class func montserrat(forTextStyle style: UIFont.TextStyle, with traits: UIFontDescriptor.SymbolicTraits? = nil) -> UIFont {
        let fontName: String

        if traits?.contains(.traitBold) ?? false && traits?.contains(.traitItalic) ?? false {
            fontName = boldItalicFontName
        }
        else if traits?.contains(.traitBold) ?? false {
            fontName = boldFontName
        }
        else if traits?.contains(.traitItalic) ?? false {
            fontName = italicFontName
        }
        else {
            fontName = defaultFontName
        }

        if let font = UIFont(name: fontName, size: baseSizes[style] ?? 17) {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        }

        // Fall back to system font.

        let font = UIFont.preferredFont(forTextStyle: style)

        if let traits = traits, let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: 0)
        }

        return font
    }

    class func montserrat(similarTo font: UIFont?, with traits: UIFontDescriptor.SymbolicTraits? = nil) -> UIFont {
        montserrat(forTextStyle: font?.fontDescriptor.object(forKey: .textStyle) as? UIFont.TextStyle ?? .body, with: traits)
    }
}


extension UILabel {

    @objc
    var fontName: String {
        get {
            font.fontName
        }
        set {
            font = UIFont(name: newValue, size: font.pointSize)
        }
    }
}

extension UIButton {

    @objc
    var fontName: String? {
        get {
            titleLabel?.fontName
        }
        set {
            if let newValue = newValue {
                titleLabel?.fontName = newValue

                if #available(iOS 15.0, *) {
                    subtitleLabel?.fontName = newValue
                }
            }
        }
    }
}

//
//  UIFont+Montserrat.swift
//  Save
//
//  Created by Benjamin Erhart on 13.06.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import FontBlaster

extension UIFont {

    static let defaultFontName = "Montserrat-Medium"
    static let boldFontName = "Montserrat-Bold"
    static let italicFontName = "Montserrat-MediumItalic"
    static let boldItalicFontName = "Montserrat-BoldItalic"
    static let blackFontName = "Montserrat-Black"
    static let semiBoldFontName = "Montserrat-SemiBold"

    static let baseSizes: [TextStyle: CGFloat] = [
        .body: 17,
        .callout: 16,
        .caption1: 12,
        .caption2: 14,
        .footnote: 13,
        .headline: 18,
        .subheadline: 15,
        .largeTitle: 36,
        .title1: 28,
        .title2: 22,
        .title3: 20,
    ]

    class func setUpMontserrat() {
        FontBlaster.blast() /* { fonts in
            print(fonts)
        } */

       // UILabel.appearance().fontName = defaultFontName
      //  UIButton.appearance().fontName = defaultFontName

        for state in [UIControl.State.application, .disabled, .focused, .highlighted, .normal, .reserved, .selected] {
            let font = UIBarItem.appearance().titleTextAttributes(for: state)?[.font] as? UIFont

            let attributes = [NSAttributedString.Key.font: montserrat(similarTo: font)]

            UIBarItem.appearance().setTitleTextAttributes(attributes, for: state)
        }

        let nba = UINavigationBarAppearance()
        nba.configureWithOpaqueBackground()

        var font = nba.titleTextAttributes[.font] as? UIFont
        nba.titleTextAttributes[.font] = montserrat(similarTo: font)

        for style in [UIBarButtonItem.Style.done, .plain] {
            let bbia = UIBarButtonItemAppearance(style: style)

            font = bbia.normal.titleTextAttributes[.font] as? UIFont
            bbia.normal.titleTextAttributes[.font] = montserrat(similarTo: font)

            font = bbia.disabled.titleTextAttributes[.font] as? UIFont
            bbia.disabled.titleTextAttributes[.font] = montserrat(similarTo: font)

            font = bbia.highlighted.titleTextAttributes[.font] as? UIFont
            bbia.highlighted.titleTextAttributes[.font] = montserrat(similarTo: font)

            font = bbia.focused.titleTextAttributes[.font] as? UIFont
            bbia.focused.titleTextAttributes[.font] = montserrat(similarTo: font)

            if style == .done {
                nba.doneButtonAppearance = bbia
            }
            else {
                nba.buttonAppearance = bbia
                nba.backButtonAppearance = bbia
            }
        }

        let a = UINavigationBar.appearance()

        a.scrollEdgeAppearance = nba
        a.compactAppearance = nba
        a.standardAppearance = nba

        if #available(iOS 15.0, *) {
            a.compactScrollEdgeAppearance = nba
        }
    }

    class func montserrat(forTextStyle style: TextStyle, with traits: UIFontDescriptor.SymbolicTraits? = nil) -> UIFont {
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
        else if traits?.contains(.traitUIOptimized) ?? false {
            fontName = semiBoldFontName
        }
        else {
            fontName = defaultFontName
        }

        if let font = UIFont(name: fontName, size: baseSizes[style] ?? 17) {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        }

        // Fall back to system font.

        let font = preferredFont(forTextStyle: style)

        if let traits = traits, let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: 0)
        }

        return font
    }

    class func montserrat(similarTo font: UIFont?, with traits: UIFontDescriptor.SymbolicTraits? = nil) -> UIFont {
        montserrat(forTextStyle: font?.fontDescriptor.object(forKey: .textStyle) as? TextStyle ?? .body, with: traits)
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

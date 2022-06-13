//
//  UIFont+Montserrat.swift
//  Save
//
//  Created by Benjamin Erhart on 13.06.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit

extension UIFont {

    static var montserrat: [UIFont.TextStyle: UIFont?] = [
        .body: UIFont(name: "Montserrat-Bold", size: 17),
        .callout: UIFont(name: "Montserrat-Bold", size: 16),
        .caption1: UIFont(name: "Montserrat-Bold", size: 12),
        .caption2: UIFont(name: "Montserrat-Bold", size: 11),
        .footnote: UIFont(name: "Montserrat-Bold", size: 13),
        .headline: UIFont(name: "Montserrat-Bold", size: 17),
        .subheadline: UIFont(name: "Montserrat-Bold", size: 15),
        .largeTitle: UIFont(name: "Montserrat-Bold", size: 34),
        .title1: UIFont(name: "Montserrat-Bold", size: 28),
        .title2: UIFont(name: "Montserrat-Bold", size: 22),
        .title3: UIFont(name: "Montserrat-Bold", size: 20),
    ]

    class func montserrat(forTextStyle style: UIFont.TextStyle) -> UIFont? {
        guard let font = montserrat[style], let font = font else {
            return nil
        }

        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }

    func bold() -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else {
            return nil
        }

        return UIFont(descriptor: descriptor, size: 0)
    }

    func italic() -> UIFont? {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return nil
        }

        return UIFont(descriptor: descriptor, size: 0)
    }
}

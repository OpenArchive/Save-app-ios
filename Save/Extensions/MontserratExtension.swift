//
//  MontserratWeight.swift
//  Save
//
//  Created by navoda on 2025-02-23.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI

enum MontserratWeight: String {
    case regular = "Montserrat-Regular"
    case medium = "Montserrat-Medium"
    case semibold = "Montserrat-SemiBold"
    case bold = "Montserrat-Bold"
    case mediumItalic  = "Montserrat-MediumItalic"
    case boldItalic = "Montserrat-BoldItalic"
}

extension Font {
    static func montserrat(_ weight: MontserratWeight, for style: Font.TextStyle) -> Font {
        let fontName = weight.rawValue
        let uiFontTextStyle = UIFont.TextStyle(style)
        let pointSize = UIFont.preferredFont(forTextStyle: uiFontTextStyle).pointSize

        if #available(iOS 14.0, *) {
            return Font.custom(fontName, size: pointSize, relativeTo: style)
        } else {
            return Font.custom(fontName, size: pointSize)
        }
    }
}

extension UIFont.TextStyle {
    init(_ swiftUIStyle: Font.TextStyle) {
        switch swiftUIStyle {
        case .largeTitle: self = .largeTitle
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .callout: self = .callout
        case .caption: self = .caption1
        case .caption2: self = .caption2
        case .footnote: self = .footnote
        default: self = .body
        }
    }
}

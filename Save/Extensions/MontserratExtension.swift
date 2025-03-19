//
//  MontserratWeight.swift
//  Save
//
//  Created by navoda on 2025-02-23.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI

extension Font {
    
    // Function to get Montserrat font with specific weight
    static func montserrat(weight: MontserratWeight = .regular, size: CGFloat) -> Font {
        return Font.custom(weight.fontName, size: size)
    }
    
    // Enum for Montserrat Font Weights
    enum MontserratWeight {
        case thin, light, regular, medium, semibold, bold, extrabold, black, italic, boldItalic
        
        var fontName: String {
            switch self {
            case .thin:
                return "Montserrat-Thin"
            case .light:
                return "Montserrat-Light"
            case .regular:
                return "Montserrat-Regular"
            case .medium:
                return "Montserrat-Medium"
            case .semibold:
                return "Montserrat-SemiBold"
            case .bold:
                return "Montserrat-Bold"
            case .extrabold:
                return "Montserrat-ExtraBold"
            case .black:
                return "Montserrat-Black"
            case .italic:
                return "Montserrat-MediumItalic"
            case .boldItalic:
                return "Montserrat-BoldItalic"
            }
        }
    }
    
    // Preset Styles for Commonly Used Text Styles
    static var largeTitleFont: Font { montserrat(weight: .bold, size: 34) }
    static var title1Font: Font { montserrat(weight: .bold, size: 28) }
    static var title2Font: Font { montserrat(weight: .medium, size: 17) }
    static var title3Font: Font { montserrat(weight: .medium, size: 20) }
    
    static var headlineFont: Font { montserrat(weight: .bold, size: 18) }
    static var headlineFont2: Font { montserrat(weight: .semibold, size: 18) }
    
    static var bodyFont: Font { montserrat(weight: .regular, size: 17) }
    static var calloutFont: Font { montserrat(weight: .regular, size: 16) }
    static var semiBoldFont: Font { montserrat(weight: .semibold, size: 16) }
    static var menuMediumFont: Font { montserrat(weight: .medium, size: 14) }
    static var bodyFont2: Font { montserrat(weight: .regular, size: 14) }
    
    static var footnoteFont: Font { montserrat(weight: .regular, size: 13) }
    static var caption1Font: Font { montserrat(weight: .regular, size: 12) }
    static var caption2Font: Font { montserrat(weight: .light, size: 11) }
    static var footnoteFontMedium: Font { montserrat(weight: .medium, size: 13) }
    static var errorText: Font { montserrat(weight: .medium, size: 11) }

    // Bold & Italic Variants
    static var bodyBoldFont: Font { montserrat(weight: .bold, size: 17) }
    static var bodyItalicFont: Font { montserrat(weight: .italic, size: 17) }
    static var menuitalicFont: Font { montserrat(weight: .italic, size: 11) }
    static var boldItalicFont: Font { montserrat(weight: .boldItalic, size: 11) }
    static var titleBoldItalicFont: Font { montserrat(weight: .boldItalic, size: 28) }
}


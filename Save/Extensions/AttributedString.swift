//
//  File.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

@available(iOS 15, *)
extension AttributedString {
    static func boldSubstring(in text: String, substring: String) -> AttributedString {
        var attributedString = AttributedString(text)
        if let range = attributedString.range(of: substring) {
            attributedString[range].font =  (.montserrat(.boldItalic, for: .caption2))
        }
        return attributedString
    }
}

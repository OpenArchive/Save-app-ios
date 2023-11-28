//
//  NSAttributedString+Utils.swift
//  Save
//
//  Created by Benjamin Erhart on 27.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

extension NSMutableAttributedString {

    var startIndex: String.Index {
        string.startIndex
    }

    var endIndex: String.Index {
        string.endIndex
    }

    func range(of aString: any StringProtocol, range: Range<String.Index>? = nil) -> Range<String.Index>? {
        string.range(of: aString, range: range)
    }

    func colorize(with color: UIColor, range: Range<String.Index>) {
        addAttribute(.foregroundColor, value: color, range: NSRange(range, in: string))
    }

    func colorize(with color: UIColor, index: String.Index) {
        colorize(with: color, range: index ..< string.index(index, offsetBy: 1))
    }

    func link(part: any StringProtocol, into label: UILabel) {
        if let range = string.range(of: part) {
            addAttributes(
                [.font: label.font.bold() ?? .boldSystemFont(ofSize: label.font.pointSize),
                 .underlineStyle: NSUnderlineStyle.single.rawValue],
                range: NSRange(range, in: string))
        }
    }
}

extension NSAttributedString {

    var isEmpty: Bool {
        string.isEmpty
    }
}

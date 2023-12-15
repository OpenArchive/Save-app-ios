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

    @discardableResult
    func colorize(with color: UIColor, range: Range<String.Index>) -> Self {
        addAttribute(.foregroundColor, value: color, range: NSRange(range, in: string))

        return self
    }

    @discardableResult
    func colorize(with color: UIColor, index: String.Index) -> Self {
        colorize(with: color, range: index ..< string.index(index, offsetBy: 1))

        return self
    }

    @discardableResult
    func link(part: (any StringProtocol)? = nil, into label: UILabel?) -> Self {
        let range: Range<String.Index>

        if let part = part, let partRange = string.range(of: part) {
            range = partRange
        }
        else {
            range = startIndex ..< endIndex
        }

        addAttributes(
            [.font: UIFont.montserrat(similarTo: label?.font, with: .traitBold),
             .underlineStyle: NSUnderlineStyle.single.rawValue],
            range: NSRange(range, in: string))

        return self
    }
}

extension NSAttributedString {

    var isEmpty: Bool {
        string.isEmpty
    }
}

extension String {

    var attributed: NSMutableAttributedString {
        NSMutableAttributedString(string: self)
    }
}

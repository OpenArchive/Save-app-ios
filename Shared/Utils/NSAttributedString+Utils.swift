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
}


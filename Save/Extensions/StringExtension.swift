//
//  StringExtension.swift
//  Save
//
//  Created by navoda on 2025-11-27.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import Foundation
import SwiftUI

extension String {
    func parseMarkdownBold(regularFont: Font, boldFont: Font, color: Color) -> Text {
        let parts = self.components(separatedBy: "**")
        var result = Text("")
        
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                // Regular text
                result = result + Text(part).font(regularFont).foregroundColor(color)
            } else {
                // Bold text
                result = result + Text(part).font(boldFont).foregroundColor(color)
            }
        }
        
        return result
    }
}

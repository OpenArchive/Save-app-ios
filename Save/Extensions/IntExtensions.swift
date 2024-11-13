//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import CoreGraphics

extension Int {
    var day: TimeInterval { 24 * 60 * 60 }
    var days: TimeInterval { Double(self) * day }
    
    var hour: TimeInterval { 60 * 60 }
    var hours: TimeInterval { Double(self) * hour }
    
    var minute: TimeInterval { 60 }
    var minutes: TimeInterval { Double(self) * minute }
    
    var second: TimeInterval { 1 }
    var seconds: TimeInterval { Double(self) }
    
    var percent: CGFloat {
        (CGFloat(self) / 100).rounded(toPlaces: 2)
    }
    
    func spelledOut() -> String {
        if self >= 1 && self <= 9 {
            return NumberFormatter.localizedString(from: NSNumber(value: self), number: .spellOut)
        }
        return String(self)
    }
}

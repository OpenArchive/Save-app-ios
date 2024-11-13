//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import CoreGraphics

extension Int {
    var day: TimeInterval { TimeIntervalConstants.secondsInDay }
    var days: TimeInterval { Double(self) * day }
    
    var hour: TimeInterval { TimeIntervalConstants.secondsInHour }
    var hours: TimeInterval { Double(self) * hour }
    
    var minute: TimeInterval { TimeIntervalConstants.secondsInMinute }
    var minutes: TimeInterval { Double(self) * minute }
    
    var second: TimeInterval { TimeIntervalConstants.secondsInSecond }
    var seconds: TimeInterval { Double(self) }
    
    var percent: CGFloat {
        (CGFloat(self) / GeneralConstants.percentBase).rounded(toPlaces:GeneralConstants.percentRoundedTo)
    }
    
    func spelledOut() -> String {
        if self >= GeneralConstants.minSpelledOutValue && self <= GeneralConstants.maxSpelledOutValue {
            return NumberFormatter.localizedString(from: NSNumber(value: self), number: .spellOut)
        }
        return String(self)
    }
}

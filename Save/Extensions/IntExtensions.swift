//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

import SweeterSwift

extension Int {
    var day: TimeInterval { return TimeInterval.day }
    var days: TimeInterval { return TimeInterval.day * Double(self) }
    
    var hour: TimeInterval { return TimeInterval.hour }
    var hours: TimeInterval { return TimeInterval.hour * Double(self) }
    
    var minute: TimeInterval { return TimeInterval.minute }
    var minutes: TimeInterval { return TimeInterval.minute * Double(self) }
    
    var second: TimeInterval { return 1 }
    var seconds: TimeInterval { return Double(self) }
    
    var percent: CGFloat {
        return (CGFloat(self) / 100.0).rounded(toPlaces: 2)
    }
    
    func spelledOut() -> String {
        if self == 1 { return "one" }
        if self == 2 { return "two" }
        if self == 3 { return "three" }
        if self == 4 { return "four" }
        if self == 5 { return "five" }
        if self == 6 { return "six" }
        if self == 7 { return "seven" }
        if self == 8 { return "eight" }
        if self == 9 { return "nine" }
        
        return String(self)
    }
}

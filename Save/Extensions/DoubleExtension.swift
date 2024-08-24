//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

extension Double {
    func asString() -> String {
        let locale = Locale(identifier: "en_US")
        
        let numberFormatter = NumberFormatter()
        
        numberFormatter.locale = locale
        numberFormatter.numberStyle = NumberFormatter.Style.currency
        
        return numberFormatter.string(from: self as NSNumber)!
    }
    
    /// Rounds the double to decimal places value
    ///
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

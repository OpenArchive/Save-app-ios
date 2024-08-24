//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Float {
    var percent: Float {
        if self < 1 { return self.rounded(toPlaces: 2) }
        
        return (self / 100.0).rounded(toPlaces: 2)
    }
    
    func rounded(toPlaces places: Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Double {
    var percent: Double {
        if self < 1 { return self.rounded(toPlaces: 2) }
        
        return (self / 100.0).rounded(toPlaces: 2)
    }
}

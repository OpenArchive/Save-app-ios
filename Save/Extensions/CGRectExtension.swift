//
//  Created by Richard Puckett on 11/28/22.
//

import UIKit

extension CGRect {
    var minEdge: CGFloat {
        return min(width, height)
    }
    
    var maxEdge: CGFloat {
        return max(width, height)
    }
    
    func setHeight(ratio: CGFloat) -> CGRect {
        .init(x: minX, y: minY, width: width, height: width / ratio)
    }
}


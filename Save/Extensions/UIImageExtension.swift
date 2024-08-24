//
//  Created by Richard Puckett on 5/30/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension UIImage {
    convenience init?(fileURLWithPath url: URL, scale: CGFloat = 1.0) {
        do {
            let data = try Data(contentsOf: url)
            self.init(data: data, scale: scale)
        } catch {
            return nil
        }
    }
}

//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class Header1: CommonHeader {
    override func setup() {
        super.setup()
        
        textColor = .header1
        font = .montserrat(forTextStyle: .headline, with: .traitBold)  // .boldMedium
    }
}

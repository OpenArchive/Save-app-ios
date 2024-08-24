//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class CommonHeader: UILabel {
    var weight: UIFont.Weight = .regular
    
    init() {
        super.init(frame: CGRect.zero)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setup() {
        numberOfLines = 0
        textAlignment = .left
        textColor = .white.withAlphaComponent(0.50)
        backgroundColor = .clear
    }
}

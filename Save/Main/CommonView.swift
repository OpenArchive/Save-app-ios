//
//  Created by Richard Puckett on 2/26/23.
//

import UIKit

class CommonView: UIView {
    var needsSetup = true
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setConstraints()
    }
    
    func setup() {
        clipsToBounds = true
    }
    
    func setConstraints() {}
}


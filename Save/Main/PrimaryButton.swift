//
//  Created by Richard Puckett on 5/25/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class PrimaryButton: UIButton {
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    convenience init(label: String) {
        self.init()
        setTitle(label)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: bounds.width, height: 60)
    }
    
//    override open var isHighlighted: Bool {
//        didSet { backgroundColor = isHighlighted ? UIColor.blue : UIColor.red }
//    }
    
    func setup() {
        backgroundColor = .formCardBackground
        setTitleColor(.header1, for: .normal)
        setTitleColor(.header2, for: .highlighted)
        titleLabel?.font = .montserrat(forTextStyle: .body, with: .classSansSerif)
        layer.borderColor = UIColor.saveBorder.cgColor
        layer.cornerRadius = AppStyle.appCornerRadius
        layer.borderWidth = AppStyle.borderWidth
    }
}

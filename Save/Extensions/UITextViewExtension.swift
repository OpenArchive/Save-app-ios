//
//  Created by Richard Puckett on 5/28/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension UITextField {
    func addDismissButton(title: String, target: Any, selector: Selector) {
        let toolBar = UIToolbar(frame: CGRect(x: 0.0,
                                              y: 0.0,
                                              width: UIScreen.main.bounds.size.width,
                                              height: 44.0))
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let barButton = UIBarButtonItem(title: title, style: .done, target: target, action: selector)
        barButton.tintColor = .header2
        
        toolBar.setItems([flexible, barButton], animated: false)
        
        inputAccessoryView = toolBar
    }
}

extension UITextView {
    func addDismissButton(title: String, target: Any, selector: Selector) {
        let toolBar = UIToolbar(frame: CGRect(x: 0.0,
                                              y: 0.0,
                                              width: UIScreen.main.bounds.size.width,
                                              height: 44.0))
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let barButton = UIBarButtonItem(title: title, style: .done, target: target, action: selector)
        barButton.tintColor = .header2
        
        toolBar.setItems([flexible, barButton], animated: false)
        
        inputAccessoryView = toolBar
    }
}

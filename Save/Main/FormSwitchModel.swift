//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

class FormSwitchModel {
    var isOn: Bool = true
    var title: String = ""
    var subTitle: String = ""
    var isEnabled: Bool = true
    var callbackOnChange: (() -> ())? = nil
    
    @discardableResult
    func onChange(_ callback: @escaping (Bool) -> Void) -> Self {
        callbackOnChange = { [weak self] in callback(self!.isOn) }
        return self
    }
}

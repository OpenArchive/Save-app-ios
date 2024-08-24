//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

struct FormSliderModel {
    var key: String?
    var title: String
    var subTitle: String
    var currentValue: Bool
    var target: AnyObject?
    var selector: Selector?
    var isEnabled: Bool = true
    var formatter: ((_ value: Any) -> String)?
    private let identifier = UUID()
}

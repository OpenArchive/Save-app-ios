//
//  Created by Richard Puckett on 8/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class CustomTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return DimmingPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

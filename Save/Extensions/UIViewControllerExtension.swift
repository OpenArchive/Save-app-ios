//
//  Created by Richard Puckett on 5/26/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

extension UIViewController {
    static func newController(withView view: UIView, frame: CGRect) -> UIViewController {
        view.frame = frame
        let controller = UIViewController()
        controller.view = view
        return controller
    }
    
    var appDelegate: AppDelegate {
        // swiftlint:disable force_cast
        return UIApplication.shared.delegate as! AppDelegate
        // swiftlint:enable force_cast
    }
    
    public func replaceRootViewController(
        withStoryboardId storyboardId: String,
        options: UIWindow.TransitionOptions = UIWindow.TransitionOptions(direction: .fade)) {
            
        guard let w = self.view.window else {
            log.warning("Unable to find view's window")
            return
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let vc = storyboard.instantiateViewController(withIdentifier: storyboardId)
        
        // w.setRootViewController(vc, options: options)
    }
    
    public func replaceRootViewController(
        withViewController vc: UIViewController,
        options: UIWindow.TransitionOptions = UIWindow.TransitionOptions(direction: .fade)) {
            
        guard let w = self.view.window else {
            log.warning("Unable to find view's window")
            return
        }
        
        // w.setRootViewController(vc, options: options)
    }
}

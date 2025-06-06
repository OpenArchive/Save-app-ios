//
//  RemoveAssetAlert.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 25.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class RemoveAssetAlert {
    
    class func present(_ vc: UIViewController, _ assets: [Asset], _ completionHandler: ((_ success: Bool) -> Void)? = nil) {
        let appName = Bundle.main.displayName
        let itemCount = assets.count
        
        let message = [
            String.localizedStringWithFormat(
                NSLocalizedString("This item/These items will be removed from the App only.", comment: "#bc-ignore!"),
                itemCount, appName),
            String.localizedStringWithFormat(
                NSLocalizedString("It/They will remain on the server and in your Photos app.", comment: "#bc-ignore!"),
                itemCount)
        ].joined(separator: "\n")
        
        let alertVC = CustomAlertViewController(
            title: String(format: NSLocalizedString("Remove Media", comment: ""), appName),
            message: message,
            primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
            primaryButtonAction: {
                for asset in assets {
                    if asset == assets.last {
                        asset.remove() {
                            completionHandler?(true)
                        }
                    } else {
                        asset.remove()
                    }
                }
            },
            secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
            secondaryButtonAction: {
                completionHandler?(false)
               
            }, showCheckbox: false, secondaryButtonIsOutlined: false,
            iconImage: Image("trash_icon"),
            iconTint: Color.redButton,
            isRemoveAlert: false
        )
        
        vc.present(alertVC, animated: true)
    }
}

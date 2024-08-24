//
//  Created by Richard Puckett on 8/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

//struct PasscodeLockConfiguration: PasscodeLockConfigurationType {
//    let repository: PasscodeRepositoryType
//    let passcodeLength = 6
//    var isTouchIDAllowed = false
//    let shouldRequestTouchIDImmediately = true
//    let maximumIncorrectPasscodeAttempts = 3
//    
//    init(repository: PasscodeRepositoryType) {
//        self.repository = repository
//    }
//    
//    init() {
//        self.repository = UserDefaultsPasscodeRepository()
//    }
//}

extension MainViewController {
    func presentSetPasscodeScreen() {
    }
    
    func presentPasscodeLockScreen() {
        var options = ALOptions()
        options.isSensorsEnabled = false
        options.onSuccessfulDismiss = { (mode: ALMode?) in
            if let mode = mode {
                print("Password \(String(describing: mode))d successfully")
            } else {
                print("User Cancelled")
            }
        }
        options.onFailedAttempt = { (mode: ALMode?) in
            print("Failed to \(String(describing: mode))")
        }
        
        AppLocker.present(with: .validate, and: options, animated: false)
    }
    
    func passcodeEntered(passcode: String, mode: OAPasscodeLockViewController.Mode) {
        switch mode {
            case .set:
                if KeychainManager.shared.savePasscode(passcode) {
                    dismiss(animated: true, completion: nil)
                } else {
                    // showAlert(title: "Error", message: "Failed to save passcode. Please try again.")
                }
            case .enter:
                if passcode == KeychainManager.shared.getPasscode() {
                    dismiss(animated: true, completion: nil)
                } else {
                    // showAlert(title: "Incorrect Passcode", message: "Please try again.")
                }
        }
    }
}

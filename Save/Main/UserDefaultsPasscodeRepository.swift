//
//  Created by Richard Puckett on 8/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//
//
//import Foundation
//
//import SwiftPasscodeLock
//
//public enum PasscodeError: Error {
//    case noPasscode
//}
//
//class UserDefaultsPasscodeRepository: PasscodeRepositoryType {
//    var passcode: [String]?
//    
//    func savePasscode(_ passcode: [String]) {
//        log.debug("savePasscode")
//    }
//    
//    func deletePasscode() {
//        log.debug("deletePasscode")
//    }
//    
//    private let passcodeKey = "passcode.lock.passcode"
//    
//    private lazy var defaults: UserDefaults = {
//        UserDefaults.standard
//    }()
//    
//    var hasPasscode: Bool {
//        if passcode != nil {
//            return true
//        }
//        
//        return false
//    }
//}

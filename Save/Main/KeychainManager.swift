//
//  Created by Richard Puckett on 8/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Security

class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    func savePasscode(_ passcode: String) -> Bool {
        let passcodeDictionary: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                                 kSecAttrAccount as String: "AppPasscode",
                                                 kSecValueData as String: passcode.data(using: .utf8)!]
        
        SecItemDelete(passcodeDictionary as CFDictionary)
        
        let status = SecItemAdd(passcodeDictionary as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
    func getPasscode() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "AppPasscode",
                                    kSecReturnData as String: true]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let passcode = String(data: retrievedData, encoding: .utf8) {
                return passcode
            }
        }
        
        return nil
    }
}

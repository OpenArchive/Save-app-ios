//
//  PasscodeRepository.swift
//  Save
//
//  Created by Elelan on 2024/12/4.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import CommonCrypto

protocol HashingStrategy {
    func hash(passcode: String, salt: Data) -> Data?
    func generateSalt() -> Data
    var saltLength: Int { get }
}

class PBKDF2HashingStrategy: HashingStrategy {
    
    private let iterations = 65536
    private let keyLength = 32 // 256 bits
    private let saltLengthBytes = 16
    
    var saltLength: Int {
        return saltLengthBytes
    }
    
    
    func generateSalt() -> Data {
        var salt = Data(count: saltLengthBytes)
        _ = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, saltLengthBytes, $0.baseAddress!)
        }
        return salt
    }
    
    func hash(passcode: String, salt: Data) -> Data? {
        
        let passwordData = Data(passcode.utf8)
        
        var hash = Data(count: keyLength)
        
        let result = hash.withUnsafeMutableBytes { hashBytes in
            
            salt.withUnsafeBytes { saltBytes in
                
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passcode,
                    passwordData.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    hashBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    keyLength
                )
            }
        }
        
        return result == kCCSuccess ? hash : nil
    }
}

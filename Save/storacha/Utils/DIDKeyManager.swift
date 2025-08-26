//
//  DIDKeyManager.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import CryptoKit

import CryptoKit

class DIDKeyManager {
    private let keychain = KeychainService.shared
    
    struct DIDKeyPair {
        let privateKey: Curve25519.Signing.PrivateKey
        let publicKey: Curve25519.Signing.PublicKey
        let did: String
    }
    
    func generateKeyPair() -> DIDKeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        // Create DID from public key using Android's logic
        let did = createDidFromPublicKey(publicKey)
        
        return DIDKeyPair(privateKey: privateKey, publicKey: publicKey, did: did)
    }
    
    /**
     * Creates DID from public key - matches Android's Ed25519Utils.createDidFromPublicKey()
     */
    private func createDidFromPublicKey(_ publicKey: Curve25519.Signing.PublicKey) -> String {
        let publicKeyData = publicKey.rawRepresentation
        
        // Create multicodec prefix for Ed25519 public key (0xed01)
        var prefixedKey = Data([0xed, 0x01])
        prefixedKey.append(publicKeyData)
        
        // Encode with base58btc and create DID
        let base58Key = prefixedKey.toBase58String()
        return "did:key:z\(base58Key)"
    }
    
    func saveKeyPair(_ keyPair: DIDKeyPair, for identifier: String) throws {
        try keychain.save(keyPair.privateKey.rawRepresentation, for: "\(identifier)_private")
        try keychain.save(keyPair.did.data(using: .utf8)!, for: "\(identifier)_did")
    }
    
    func loadKeyPair(for identifier: String) throws -> DIDKeyPair {
        let privateKeyData = try keychain.load(for: "\(identifier)_private")
        let didData = try keychain.load(for: "\(identifier)_did")
        
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let did = String(data: didData, encoding: .utf8)!
        
        return DIDKeyPair(privateKey: privateKey, publicKey: privateKey.publicKey, did: did)
    }
    
    func signChallenge(_ challenge: String, with privateKey: Curve25519.Signing.PrivateKey) throws -> String {
        let challengeData = challenge.data(using: .utf8)!
        let signature = try privateKey.signature(for: challengeData)
        return signature.base64EncodedString()
    }
}

// MARK: - Base58 Extension (needed for proper DID creation)

extension Data {
    func toBase58String() -> String {
        guard !isEmpty else { return "" }
        
        // Base58 alphabet (Bitcoin/IPFS standard)
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        let alphabetArray = Array(alphabet)
        
        // Count leading zeros
        var leadingZeros = 0
        for byte in self {
            if byte == 0 {
                leadingZeros += 1
            } else {
                break
            }
        }
        
        // Convert bytes to base58 using division method
        var bytes = Array(self)
        var encoded = ""
        
        while !bytes.allSatisfy({ $0 == 0 }) {
            var carry = 0
            for i in 0..<bytes.count {
                carry = carry * 256 + Int(bytes[i])
                bytes[i] = UInt8(carry / 58)
                carry %= 58
            }
            encoded = String(alphabetArray[carry]) + encoded
        }
        
        // Add leading '1's for each leading zero byte
        let leadingOnes = String(repeating: "1", count: leadingZeros)
        
        return leadingOnes + encoded
    }
}

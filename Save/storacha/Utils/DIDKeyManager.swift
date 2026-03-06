//
//  DIDKeyManager.swift
//  Save
//
//  Created by navoda on 2025-08-22.
//  Copyright © 2025 Open Archive. All rights reserved.
//

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
    
    /**
     * Validates a DID key format and structure
     */
    func isValidDid(_ did: String) -> Bool {
        do {
            // Check basic format
            guard did.hasPrefix("did:key:z") else { return false }
            
            // Must have content after "did:key:z"
            guard did.count > 9 else { return false }
            
            let base58Part = String(did.dropFirst(9))
            
            // Base58 part should not be empty
            guard !base58Part.isEmpty else { return false }
            
            // Try to decode and validate the structure
            let multicodecKey = try decodeBase58(base58Part)
            
            // Check multicodec prefix for Ed25519 (0xed01) and minimum length
            guard multicodecKey.count >= 34 else { return false }
            guard multicodecKey[0] == 0xed && multicodecKey[1] == 0x01 else { return false }
            
            // Extract the public key (32 bytes from index 2 to 33)
            let publicKeyBytes = multicodecKey[2...33]
            
            // Validate it's 32 bytes and can be used as a Curve25519 public key
            guard publicKeyBytes.count == 32 else { return false }
            _ = try Curve25519.Signing.PublicKey(rawRepresentation: Data(publicKeyBytes))
            
            return true
        } catch {
            return false
        }
    }
    
    /**
     * Decodes a Base58 encoded string to Data
     */
    private func decodeBase58(_ string: String) throws -> Data {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var decoded: [UInt8] = [0]
        
        for char in string {
            guard let index = alphabet.firstIndex(of: char) else {
                throw NSError(domain: "Base58", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Base58 character"])
            }
            
            var carry = alphabet.distance(from: alphabet.startIndex, to: index)
            
            for i in 0..<decoded.count {
                carry += Int(decoded[i]) * 58
                decoded[i] = UInt8(carry & 0xff)
                carry >>= 8
            }
            
            while carry > 0 {
                decoded.append(UInt8(carry & 0xff))
                carry >>= 8
            }
        }
        
        // Add leading zeros
        for char in string {
            if char == "1" {
                decoded.append(0)
            } else {
                break
            }
        }
        
        return Data(decoded.reversed())
    }
    
    func saveKeyPair(_ keyPair: DIDKeyPair) throws {
    
        do {
            try keychain.save(keyPair.privateKey.rawRepresentation, for: "key_private")
        } catch {
            throw error
        }
        
        do {
            try keychain.save(keyPair.did.data(using: .utf8)!, for: "key_did")
    
        } catch {
            throw error
        }
        
    }

    func loadKeyPair() throws -> DIDKeyPair {
     
        let privateKeyData: Data
        do {
            privateKeyData = try keychain.load(for: "key_private")
        } catch {
            throw error
        }
        
        let didData: Data
        do {
            didData = try keychain.load(for: "key_did")
        } catch {
            throw error
        }
        
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

//
//  SecureEnclave.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.11.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Foundation
import LocalAuthentication

/**
 Encapsulates all cryptography where the secure enclave is used.

 References:
 https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_secure_enclave
 https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
 */
class SecureEnclave: NSObject {

    /**
     Tag of the single private key we're using.
     */
    static let tag = Bundle.main.displayName.data(using: .utf8)!

    private static let laContext = LAContext()

    /**
     Create a private/public key pair using our one tag inside the secure enclave.
     Don't call this, if there's already one existing!

     The key can be used by the user when entering the device passcode or using any enrolled biometry.

     The key will be stored on this device only.

     - returns: The reference to the created private key or `nil` if something goes horribly wrong.
     */
    @discardableResult
    class func createKey() -> SecKey? {
        let flags: SecAccessControlCreateFlags = [.privateKeyUsage, .userPresence]

        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags, nil)
        else {
            return nil
        }

        // Only elliptic curve 256 bit keys can be created inside the secure enclave.
        // So don't mess with these parameters!
        let parameters: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag,
                kSecAttrAccessControl: access] as [CFString : Any]]

        return SecKeyCreateRandomKey(parameters as CFDictionary, nil)
    }

    /**
     Load the private key from the secure enclave.

     - returns: the reference to the private key or `nil` if there is no key to be found under our `tag`.
     */
    class func loadKey() -> SecKey? {
        var item: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeEC,
            kSecReturnRef: true]

        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
            return (item as! SecKey)
        }

        return nil
    }

    /**
     Removes the created key from the secure enclave.

     - returns: `true` on success, `false` on failure.
     */
    class func removeKey() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: tag,
            kSecAttrKeyType: kSecAttrKeyTypeEC]

        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    /**
     - parameter key: A private key.
     - returns: the public key of the given private key or `nil` if something goes horribly wrong.
     */
    class func getPublicKey(_ key: SecKey?) -> SecKey? {
        guard let key = key else {
            return nil
        }

        return SecKeyCopyPublicKey(key)
    }

    /**
     Sign a given piece of data with the given private key.

     - parameter data: Data to sign.
     - parameter key: Private key to use for the signature.
     - returns: the signature, or `nil` if `data` or `key` is `nil` or if something goes horribly wrong.
     */
    class func sign(_ data: Data?, with key: SecKey?) -> Data? {
        guard let data = data, let key = key else {
            return nil
        }

        return SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256,
                                     data as CFData, nil) as Data?
    }

    /**
     Sign a given string with the given private key.

     - parameter data: String to sign.
     - parameter key: Private key to use for the signature.
     - returns: the signature as BASE64-encoded string, or `nil` if `data` or `key` is `nil` or if something goes horribly wrong.
     */
    class func sign(_ data: String?, with key: SecKey?) -> String? {
        (sign(data?.data(using: .utf8), with: key) as? NSData)?.base64EncodedString()
    }

    /**
     Verifies a signature on a given piece of data.

     - parameter data: The data, which was signed.
     - parameter signature: The signature which was produced by `#sign`.
     - parameter publicKey: The public key of the private key with which this signature was created.
     - returns: true if signature is valid, false if invalid or if `data`, `signature` or `publicKey` was nil.
     */
    class func verify(_ data: Data?, signature: Data?, with publicKey: SecKey?) -> Bool {
        guard let data = data, let signature = signature, let publicKey = publicKey else {
            return false
        }

        return SecKeyVerifySignature(publicKey, .ecdsaSignatureMessageX962SHA256,
                                     data as CFData, signature as CFData, nil)
    }

    /**
     Verifies a signature on a given string.

     - parameter data: The string, which was signed.
     - parameter signature: The signature which was produced by `#sign` as a BASE64 encoded string.
     - parameter publicKey: The public key of the private key with which this signature was created.
     - returns: true if signature is valid, false if invalid or if `data`, `signature` or `publicKey` was nil.
     */
    class func verify(_ data: String?, signature: String?, with publicKey: SecKey?) -> Bool {
        guard let signature = signature else {
            return false
        }

        return verify(data?.data(using: .utf8), signature: NSData(base64Encoded: signature) as Data?, with: publicKey)
    }

    /**
     Encrypts a given plaintext.

     - parameter plaintext: The plaintext to encrypt.
     - parameter publicKey: A public key.
     - returns: the encrypted ciphertext or `nil` if `plaintext` or `publicKey` is `nil` or something goes horribly wrong.
     */
    class func encrypt(_ plaintext: String?, with publicKey: SecKey?) -> Data? {
        guard let plaintext = plaintext?.data(using: .utf8),
              let publicKey = publicKey,
              let data = SecKeyCreateEncryptedData(publicKey, .eciesEncryptionCofactorVariableIVX963SHA224AESGCM, plaintext as CFData, nil)
        else {
            return nil
        }

        return data as Data
    }

    /**
     Decrypts a given ciphertext.

     - parameter cyphertext: The cyphertext data to decrypt.
     - parameter key: A secret key.
     - returns: the decrypted plaintext or `nil`, if `ciphertext` or `key` is `nil` or the plaintext cannot be encoded as UTF-8 or something goes horribly wrong.
     */
    class func decrypt(_ ciphertext: Data?, with key: SecKey?) -> String? {
        guard let ciphertext = ciphertext,
              let key = key,
              let data = SecKeyCreateDecryptedData(key, .eciesEncryptionCofactorVariableIVX963SHA224AESGCM, ciphertext as CFData, nil)
        else {
            return nil
        }

        return String(data: data as Data, encoding: .utf8)
    }

    /**
     Creates a nonce from a UUID.

     - returns: the nonce or `nil` if UTF-8 encoding of the nonce fails.
     */
    class func getNonce() -> Data? {
        return UUID().uuidString.data(using: .utf8)
    }

    class func deviceSecured() -> Bool {
        return laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    class func biometryType() -> LABiometryType {
        _ = deviceSecured() // Needs to be called, first, in order for the next value to be set.

        return laContext.biometryType
    }
}

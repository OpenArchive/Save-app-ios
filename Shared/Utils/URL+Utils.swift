//
//  URL+Utils.swift
//  Save
//
//  Created by Benjamin Erhart on 06.03.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Foundation
import LibProofMode

extension URL {

    static var groupDir: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroup)
    }

    static var proofModePrivateKey: URL? {
        Proof.shared.defaultDocumentFolder?.appendingPathComponent("pkr.asc")
    }

    static var proofModePublicKey: URL? {
        guard let url = Proof.shared.defaultDocumentFolder?.appendingPathComponent("pub.asc") else {
            return nil
        }

        // Workaround for newer ProofMode versions, which don't store the public
        // key file anymore. We need it, hence we create it here.
        if !url.exists {
            let key = Proof.shared.getPublicKeyString()
            try? key?.write(to: url, atomically: true, encoding: .ascii)
        }

        return url
    }

    var exists: Bool {
        (try? checkResourceIsReachable()) ?? false
    }

    var size: Int? {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}

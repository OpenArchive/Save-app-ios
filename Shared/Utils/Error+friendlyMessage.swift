//
//  Error+friendlyMessage.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 19.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation

extension Error {

    /// Offline / path-loss style `URLError`s — retried automatically when reachability returns (upload stays unpaused unless max retries / SaveError). Includes `cannotConnectToHost` for common “no route” cases.
    var isLikelyConnectivityFailure: Bool {
        let ns = self as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        switch ns.code {
        case URLError.notConnectedToInternet.rawValue,
             URLError.networkConnectionLost.rawValue,
             URLError.cannotConnectToHost.rawValue,
             URLError.dataNotAllowed.rawValue,
             URLError.internationalRoamingOff.rawValue,
             URLError.callIsActive.rawValue,
             URLError.dnsLookupFailed.rawValue:
            return true
        default:
            return false
        }
    }

    var friendlyMessage: String {
        if let error = self as? SaveError {
            switch error {
            case .http(let status) where status == 401:
                return NSLocalizedString("Incorrect username or password", comment: "")

            default:
                // For an unkown reason, casting self gives a better error
                // message, so that's actually not the same as the general
                // fallback below.
                return error.localizedDescription
            }
        }

        // Google Drive errors
        if (self as NSError).userInfo["data_content_type"] as? String == "application/json; charset=UTF-8",
           let data = (self as NSError).userInfo["data"] as? Data,
           let googleError = try? JSONDecoder().decode(GoogleErrorWrapper.self, from: data)
        {
            return googleError.error.description
        }

        return localizedDescription
    }
}

struct GoogleErrorWrapper: Codable {

    let error: GoogleError
}

struct GoogleError: Codable, CustomStringConvertible {

    let code: Int?

    let message: String?

    let domain: String?

    let reason: String?

    let errors: [GoogleError]?

    var description: String {
        var pieces = [String]()

        let message = message ?? errors?.first?.message

        if let code = code ?? errors?.first?.code {
            pieces.append("code=\(code)")
        }

        if let domain = domain ?? errors?.first?.domain {
            pieces.append("domain=\(domain)")
        }

        if let reason = reason ?? errors?.first?.reason {
            pieces.append("reason=\(reason)")
        }

        return "\(message ?? "") (\(pieces.joined(separator: ", ")))"
    }
}

//
//  NSError+from.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 21.02.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import Foundation
import SwiftyDropbox

extension NSError {

    class func from<T: CustomStringConvertible>(_ callError: CallError<T>?) -> NSError? {
        guard let callError = callError else {
            return nil
        }

        var domain = String(describing: type(of: callError))
        var code = -1
        var description = callError.description

        switch callError {
        case .internalServerError(let dbCode, let message, _ /* requestId */):
            code = dbCode

            if let message = message {
                description = message
            }

        case .badInputError(let message, _ /* requestId */):
            if let message = message {
                description = message
            }

        case .rateLimitError(let error, _, _, _ /* requestId */):
            domain = String(describing: type(of: error))

            if let reason = SerializeUtil.prepareJSONForSerialization(Auth.RateLimitReasonSerializer().serialize(error.reason)) as? [AnyHashable: String],
               let key = reason.keys.first,
               let value = reason[key]
            {
                description = value
            }
            else {
                description = error.reason.description
            }

        case .httpError(let dbCode, let message, _ /* requestId */):
            if let dbCode = dbCode {
                code = dbCode
            }

            if let message = message {
                description = message
            }

        case .authError(let error, _, _, _ /* requestId */):
            domain = String(String(describing: type(of: error)))

            if let reason = SerializeUtil.prepareJSONForSerialization(Auth.AuthErrorSerializer().serialize(error)) as? [AnyHashable: String],
               let key = reason.keys.first,
               let value = reason[key]
            {
                description = value
            }
            else {
                description = error.description
            }

        case .accessError(let error, _, _, _ /* requestId */):
            domain = String(String(describing: type(of: error)))

            if let reason = SerializeUtil.prepareJSONForSerialization(Auth.AccessErrorSerializer().serialize(error)) as? [AnyHashable: String],
               let key = reason.keys.first,
               let value = reason[key]
            {
                description = value
            }
            else {
                description = error.description
            }

        case .routeError(let box, _, let tags, _ /* requestId */):
            if let tags = tags {
                description = tags
            }

            if let error = box.unboxed as? Files.UploadError {
                domain = String(describing: type(of: error))

                switch error {
                case .path(let uploadWriteFailed):
                    if let reason = SerializeUtil.prepareJSONForSerialization(
                        Files.WriteErrorSerializer().serialize(uploadWriteFailed.reason)) as? [AnyHashable: String],
                       let key = reason.keys.first,
                       let value = reason[key]
                    {
                        description = value
                    }
                    else {
                        description = uploadWriteFailed.reason.description
                    }

                case .propertiesError(let invalidPropertyGroupError):
                    description = invalidPropertyGroupError.description

                default:
                    description = error.description
                }
            }

        case .clientError(let error):
            if let error = error {
                return error as NSError
            }
        }

        return NSError(
            domain: domain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description])
    }
}

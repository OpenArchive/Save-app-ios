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

        return NSError(
            domain: String(describing: type(of: callError)),
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: callError.description])
    }
}

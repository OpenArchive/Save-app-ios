//
//  Request+debug.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import Foundation
import Alamofire

extension Request {
    public func debug() -> Self {
        #if DEBUG
            print("=======================================")
            debugPrint(self)
            print("=======================================")
        #endif

        return self
    }
}

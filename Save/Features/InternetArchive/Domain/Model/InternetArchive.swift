//
//  InternetArchive.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

struct InternetArchive {
    let metaData: MetaData
    let auth: Auth
    
    struct MetaData {
        let screenName: String
        let userName: String
        let email: String
    }
    
    struct Auth {
        let access: String
        let secret: String
    }
}

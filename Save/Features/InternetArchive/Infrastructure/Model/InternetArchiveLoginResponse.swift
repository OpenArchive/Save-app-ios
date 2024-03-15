//
//  InternetArchiveLoginResponse.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

struct InternetArchiveLoginResponse : Codable{
    let success: Bool
    let values: Values
    let version: Int
    
    struct Values : Codable {
        let s3: S3?
        let screenname: String?
        let email: String?
        let itemname: String?
        let reason: String?
    }
    
    struct S3 : Codable {
        let access: String
        let secret: String
    }
}

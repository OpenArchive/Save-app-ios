//
//  InternetArchiveMapper.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

class InternetArchiveMapper {
    func map(response: InternetArchiveLoginResponse) -> InternetArchive? {
         guard let s3 = response.values.s3 else {
            return nil
        }
        
        let metaData = InternetArchive.MetaData(
            screenName: response.values.screenname ?? "",
            userName: response.values.itemname ?? "",
            email: response.values.email ?? ""
        )
        
        return InternetArchive(metaData: metaData, auth: InternetArchive.Auth(access: s3.access, secret: s3.secret))
    }
}

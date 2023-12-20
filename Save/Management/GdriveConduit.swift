//
//  GdriveConduit.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

class GdriveConduit: Conduit {

    static var user: GIDGoogleUser? = nil

    class var service: GTLRDriveService {
        let service = GTLRDriveService()
        service.authorizer = user?.fetcherAuthorizer

        return service
    }
}

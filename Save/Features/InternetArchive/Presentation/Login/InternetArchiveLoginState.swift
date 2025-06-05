//
//  InternetArchiveLoginState.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct InternetArchiveLoginState {
    private(set) var userName: String = ""
    private(set) var password: String = ""
    private(set) var isLoginError: Bool = false
    private(set) var isValid: Bool = false
    private(set) var isBusy: Bool = false
    
    func copy(
         userName: String? = nil,
         password: String? = nil,
         isLoginError: Bool? = nil,
         isValid: Bool? = nil,
         isBusy: Bool? = nil
    ) -> InternetArchiveLoginState {
        var copy = self
        copy.userName = userName ?? self.userName
        copy.password = password ?? self.password
        copy.isLoginError = isLoginError ?? self.isLoginError
        copy.isValid = isValid ?? self.isValid
        copy.isBusy = isBusy ?? self.isBusy
        return copy
    }
    
    struct Bindings {
        // Two-way bindings
        var userName: Binding<String>
        var password: Binding<String>
        let isLoginError: Bool
        let isBusy: Bool
        let isValid: Bool
    }
}


enum InternetArchiveLoginAction {
    case Login
    case LoggedIn
    case LoginError
    case Next
    case Cancel
    case UpdateEmail(_ value: String)
    case UpdatePassword(_ value: String)
    case CreateAccount
    case isLoginOnprogress
    case isLoginFinished
}

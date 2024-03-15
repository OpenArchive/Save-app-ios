//
//  InternetArchiveLoginState.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

class InternetArchiveLoginState: ObservableObject {
    @Published var userName: String = ""
    @Published var password: String = ""
    private(set) var isLoginError: Bool = false
    private(set) var isValid: Bool = false
    
    func copy(
         userName: String? = nil,
         password: String? = nil,
         isLoginError: Bool? = nil,
         isValid: Bool? = nil
    ) -> InternetArchiveLoginState {
        var copy = self
        copy.userName = userName ?? self.userName
        copy.password = password ?? self.password
        copy.isLoginError = isLoginError ?? self.isLoginError
        copy.isValid = isValid ?? self.isValid
        return copy
    }
}

enum LoginAction {
    case Login
    case LoggedIn
    case LoginError
    case Cancel
    case UpdateEmail(_ value: String)
    case UpdatePassword(_ value: String)
}

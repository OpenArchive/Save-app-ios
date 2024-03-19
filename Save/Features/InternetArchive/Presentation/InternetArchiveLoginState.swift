//
//  InternetArchiveLoginState.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

class InternetArchiveLoginState {
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
        let copy = self
        copy.userName = userName ?? self.userName
        copy.password = password ?? self.password
        copy.isLoginError = isLoginError ?? self.isLoginError
        copy.isValid = isValid ?? self.isValid
        copy.isBusy = isBusy ?? self.isBusy
        return copy
    }
}

// binds state to the swift UI
class InternetArchiveLoginViewState: ObservableObject {
    // Two-way bindings
    var userName: Binding<String>
    var password: Binding<String>
    
    // One-way bindings
    var isValid: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    var isLoginError: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    var isBusy: Bool = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    init(userName: Binding<String>, password: Binding<String>) {
        self.userName = userName
        self.password = password
    }
}

enum LoginAction {
    case Login
    case LoggedIn
    case LoginError
    case Cancel
    case UpdateEmail(_ value: String)
    case UpdatePassword(_ value: String)
    case CreateAccount
}

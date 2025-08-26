//
//  InternetArchiveViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

class InternetArchiveLoginViewModel : StoreViewModel<InternetArchiveLoginState, InternetArchiveLoginAction> {
    typealias Action = InternetArchiveLoginAction
    typealias State = InternetArchiveLoginState
    
    private let useCase: InternetArchiveLoginUseCase
    
    init(useCase: InternetArchiveLoginUseCase) {
        self.useCase = useCase
        super.init(initialState: InternetArchiveLoginState())
        self.store.set(reducer: self.reduce)
        self.store.set(effects: self.effects)
    }
    
    func state() -> State.Bindings {
        State.Bindings(
            userName: self.store.bind(\.userName) { .UpdateEmail($0) },
            password: self.store.bind(\.password) { .UpdatePassword($0) },
            isLoginError: self.store.dispatcher.state.isLoginError,
            isBusy: self.store.dispatcher.state.isBusy,
            isValid: self.store.dispatcher.state.isValid
        )
    }
    
    // updates read-only state, copying structs is effecient in swift, but could be inout
    private func reduce(state: InternetArchiveLoginState, action: Action) -> InternetArchiveLoginState? {
        return switch action {
        case .UpdateEmail(let value):
            state.copy(userName: value, isValid: validateCredentials(value, state.password))
        case .UpdatePassword(let value):
            state.copy(password: value, isValid: validateCredentials(state.userName, value))
        case .Login:
            state.copy(isBusy: true)
        case .LoginError:
            state.copy(isLoginError: true, isBusy: false)
        case .LoggedIn:
            state.copy(isBusy: false)
        default:
            nil
        }
    }
    
    private func validateCredentials(_ email: String, _ password: String) -> Bool {
        return !email.isEmpty && !password.isEmpty
    }
    
    // applies side effects to store state and returns a value to keep in scope
    private func effects(state: InternetArchiveLoginState, action: Action) -> Scoped? {
        switch action {
        case .Login:
            self.store.notify(.isLoginOnprogress)
            return useCase(email: state.userName, password: state.password, completion: { result in
                switch result {
                case .success:
                    self.store.notify(.isLoginFinished)
                    self.store.dispatch(.LoggedIn)
                case .failure(_):
                    self.store.notify(.isLoginFinished)
                    self.store.dispatch(.LoginError)
                }
            })
        case .LoggedIn:
            self.store.notify(.Next)
        case .Cancel:
            self.store.notify(.Cancel)
        case .CreateAccount:
            UIApplication.shared.open(URL(string: "https://archive.org/account/signup")!)
        default: break
        }
        
        return nil
    }
}

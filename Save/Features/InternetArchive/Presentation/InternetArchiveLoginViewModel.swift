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
import CleanInsightsSDK

class InternetArchiveLoginViewModel : ObservableObject, Stateful {
    typealias Action = LoginAction
    typealias State = InternetArchiveLoginViewState
    
    // all publishers are stored in the provided scope
    let scope: StoreScope
    
    private let useCase: InternetArchiveLoginUseCase
    
    // The store:
    //  - allows the view model to be observed via actions
    //  - keeps state unidirectional and read only
    //  - ensures all background effects are scoped
    private(set) lazy var store = {
        StateStore(
            scope: scope,
            initialState: InternetArchiveLoginState(),
            reducer: combine(self.reduce, self.update),
            effects: self.effects
        )
    }()

    // View State holds the custom SwiftUI binding for the store
    // essentially an observable mapping
    lazy var state = {
        InternetArchiveLoginViewState(
            userName: Binding(
                get: { self.store.state.userName },
                set: { email in self.store.dispatch(.UpdateEmail(email)) }
            ),
            password: Binding(
                get: { self.store.state.password },
                set: { pwd in self.store.dispatch(.UpdatePassword(pwd)) }
            )
        )
    }()
            
    init(scope: StoreScope, useCase: InternetArchiveLoginUseCase) {
        self.scope = scope
        self.useCase = useCase
    }
    
    // updates read-only state, copying structs is effecient in swift
    private func reduce(state: InternetArchiveLoginState, action: Action) -> InternetArchiveLoginState {
        return switch action {
        case .UpdateEmail(let value):
            state.copy(userName: value)
        case .LoginError:
            state.copy(isLoginError: true)
        default:
            state
        }
    }
    
    // updates the binding view one-way state to trigger UI changes
    private func update(state: InternetArchiveLoginState, action: Action) -> InternetArchiveLoginState {
        DispatchQueue.main.async {
            self.state.isLoginError = state.isLoginError
            self.state.isValid = state.isValid
        }
        return state
    }
    
    // applies side effects to store state and returns a value to keep in scope
    private func effects(state: InternetArchiveLoginState, action: Action) -> Scoped {
        return switch action {
        case .Login:
            useCase(email: state.userName, password: state.password, completion: { result in
                switch result {
                case .success:
                    self.store.notify(.LoggedIn)
                case .failure(_):
                    self.store.dispatch(.LoginError)
                }
            })
        default:
            emptyEffect()
        }
    }
}

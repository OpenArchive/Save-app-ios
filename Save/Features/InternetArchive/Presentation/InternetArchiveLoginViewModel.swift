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
    typealias State = InternetArchiveLoginState
    
    private let repository: InternetArchiveRepository
    
    private(set) lazy var store = {
        StateStore<InternetArchiveLoginState, Action>(
            initialState: InternetArchiveLoginState(),
            reducer: self.reduce,
            effects: self.effects
        )
    }()

    private(set) lazy var state: InternetArchiveLoginState = { self.store.state }()
    
    init(repository: InternetArchiveRepository) {
        self.repository = repository
    }

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
    
    private func effects(state: InternetArchiveLoginState, action: Action) -> AnyCancellable {
        return switch action {
        case .Login:
            // TODO: use case
            repository.login(email: state.userName, password: state.password)
                .sink(receiveCompletion: { result in
                    switch result {
                    case .finished:
                        self.store.notify(.LoggedIn)
                    case .failure(_):
                        self.store.dispatch(.LoginError)
                    }
                }, receiveValue: { result in
                    
                    let space = IaSpace(accessKey: result.auth.access, secretKey: result.auth.secret)

                    SelectedSpace.space = space

                    Db.writeConn?.asyncReadWrite() { tx in
                        SelectedSpace.store(tx)

                        tx.setObject(space)
                    }

                    CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: space.name)

                })
        default:
            emptyEffect()
        }
    }
    
    
}

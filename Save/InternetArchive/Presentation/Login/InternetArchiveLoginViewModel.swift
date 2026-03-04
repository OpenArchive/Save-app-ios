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

final class InternetArchiveLoginViewModel: ObservableObject {

    private let useCase: InternetArchiveLoginUseCase
    private var loginSubscription: Scoped?

    @Published var userName: String = "" {
        didSet { isValid = validateCredentials() }
    }
    @Published var password: String = "" {
        didSet { isValid = validateCredentials() }
    }
    @Published private(set) var isLoginError: Bool = false
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var isValid: Bool = false

    var onNext: ((IaSpace) -> Void)?
    var onCancel: (() -> Void)?
    var onLoginProgress: ((Bool) -> Void)?

    init(useCase: InternetArchiveLoginUseCase) {
        self.useCase = useCase
    }

    func updateEmail(_ value: String) {
        userName = value
    }

    func updatePassword(_ value: String) {
        password = value
    }

    func clearError() {
        isLoginError = false
    }

    func login() {
        guard !isBusy, isValid else { return }
        isBusy = true
        onLoginProgress?(true)

        loginSubscription = useCase(email: userName, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.isBusy = false
                self?.onLoginProgress?(false)
                switch result {
                case .success(let space):
                    self?.onNext?(space)
                case .failure:
                    self?.isLoginError = true
                }
            }
        }
    }

    func cancel() {
        onCancel?()
    }

    func createAccount() {
        if let url = URL(string: "https://archive.org/account/signup") {
            UIApplication.shared.open(url)
        }
    }

    private func validateCredentials() -> Bool {
        !userName.isEmpty && !password.isEmpty
    }
}

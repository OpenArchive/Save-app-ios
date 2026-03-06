//
//  PinCreateViewModel.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

final class PasscodeSetupViewModel: ObservableObject {

    private let appConfig: AppConfig
    private let repository: PasscodeRepository
    private var cancellable = Set<AnyCancellable>()

    var passcodeLength: Int { appConfig.passcodeLength }

    @Published var passcode: String = ""
    private var confirmPasscode: String = ""
    @Published var isConfirming: Bool = false
    @Published var isProcessing: Bool = false
    @Published var shouldShake: Bool = false
    @Published var showPasswordMismatch: Bool = false

    var onComplete: ((Bool) -> Void)?

    init(
        config: AppConfig = .default,
        repository: PasscodeRepository = PasscodeRepository()
    ) {
        self.appConfig = config
        self.repository = repository
    }

    func onNumberClick(number: String) {
        guard !isProcessing, passcode.count < appConfig.passcodeLength else { return }
        passcode += number
    }

    func onBackspaceClick() {
        guard !isProcessing, !passcode.isEmpty else { return }
        passcode.removeLast()
    }

    func onEnterClick() {
        guard !isProcessing, !passcode.isEmpty else { return }
        if passcode.count == appConfig.passcodeLength {
            isProcessing = true
            processPasscodeEntry()
        }
    }

    func cancel() {
        onComplete?(false)
    }

    private func processPasscodeEntry() {
        if !isConfirming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.confirmPasscode = self.passcode
                self.passcode = ""
                self.isConfirming = true
                self.isProcessing = false
            }
        } else {
            if passcode == confirmPasscode {
                hashPasscode()
            } else {
                showPasswordMismatch = true
                triggerShakeAnimation()
            }
        }
    }

    private func hashPasscode() {
        let salt = repository.generateSalt()

        repository.hashPasscode(passcode: passcode, salt: salt)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        #if DEBUG
                        print("Hashing error")
                        #endif
                        self?.triggerShakeAnimation()
                    }
                },
                receiveValue: { [weak self] hash in
                    guard let self else { return }
                    do {
                        try self.repository.storePasscodeHashAndSalt(hash: hash, salt: salt)
                        #if DEBUG
                        print("Hashed passcode: \(hash)")
                        #endif
                        self.onComplete?(true)
                    } catch {
                        #if DEBUG
                        print("Error storing passcode: \(error)")
                        #endif
                        self.triggerShakeAnimation()
                    }
                }
            )
            .store(in: &cancellable)
    }

    private func resetState() {
        passcode = ""
        confirmPasscode = ""
        isConfirming = false
        isProcessing = false
        shouldShake = false
        showPasswordMismatch = false
    }

    private func triggerShakeAnimation() {
        DispatchQueue.main.async { [weak self] in
            self?.shouldShake = true
        }
    }

    func onAnimationCompleted() {
        DispatchQueue.main.async { [weak self] in
            self?.shouldShake = false
            self?.resetState()
        }
    }
}

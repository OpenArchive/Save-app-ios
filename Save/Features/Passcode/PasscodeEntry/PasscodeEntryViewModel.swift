//
//  PasscodeEntryViewModel.swift
//  Save
//
//  Created by Elelan on 2024/12/2.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import Combine

class PasscodeEntryViewModel: ObservableObject {
    @Published var passcode: String = ""
    @Published var shouldShake: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLockedOut: Bool = false
    @Published var remainingAttempts: Int? = nil
    @Published var lockoutTimer: Int = 0
    
    private let pinLength = 6
    private let maxAttempts = 5
    private let lockoutDuration = 30 // in seconds
    
    private var failedAttempts = 0
    private var cancellables = Set<AnyCancellable>()
    
    var onPasscodeSuccess: () -> Void
    var onExit: () -> Void
    
    init(onPasscodeSuccess: @escaping () -> Void, onExit: @escaping () -> Void) {
        self.onPasscodeSuccess = onPasscodeSuccess
        self.onExit = onExit
    }
    
    func onNumberClick(_ number: String) {
        guard !isLockedOut else { return }
        
        if passcode.count < pinLength {
            passcode.append(number)
        }
        
        if passcode.count == pinLength {
            validatePasscode()
        }
    }
    
    func onBackspaceClick() {
        guard !isLockedOut, !passcode.isEmpty else { return }
        passcode.removeLast()
    }
    
    private func validatePasscode() {
        let correctPin = "123456" // Replace with actual validation logic
        if passcode == correctPin {
            onPasscodeSuccess()
        } else {
            failedAttempts += 1
            if failedAttempts >= maxAttempts {
                triggerLockout()
            } else {
                errorMessage = "Incorrect passcode. \(maxAttempts - failedAttempts) attempts remaining."
                triggerShakeAnimation()
            }
        }
        passcode = ""
    }
    
    private func triggerShakeAnimation() {
        shouldShake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldShake = false
        }
    }
    
    private func triggerLockout() {
        isLockedOut = true
        lockoutTimer = lockoutDuration
        
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .scan(lockoutDuration) { remaining, _ in remaining - 1 }
            .sink { remaining in
                self.lockoutTimer = remaining
                if remaining <= 0 {
                    self.isLockedOut = false
                    self.failedAttempts = 0
                }
            }
            .store(in: &cancellables)
    }
}

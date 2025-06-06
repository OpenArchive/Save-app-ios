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
    @Published var isProcessing: Bool = false
    @Published var shouldShake: Bool = false
    
    private let appConfig: AppConfig
    private let repository: PasscodeRepository
    
    private let onComplete: () -> Void
    
    init (
        appConfig: AppConfig = .default,
        passcodeRepository: PasscodeRepository = PasscodeRepository(),
        onComplete: @escaping () -> Void
    ) {
        self.appConfig = appConfig
        self.repository = passcodeRepository
        self.onComplete = onComplete
    }
    
    var passcodeLength: Int {
        get { appConfig.passcodeLength }
    }
    
    private var cancellable = Set<AnyCancellable>()
    
    
    
    func onNumberClick(_ number: String) {
        
        guard !isProcessing, passcode.count < appConfig.passcodeLength else { return }
        
        passcode += number
        
        
    }
    func onEnterClick() {
        guard !isProcessing, !passcode.isEmpty else { return }
        if passcode.count == appConfig.passcodeLength {
            
            isProcessing = true
            checkPasscode()
        }
    }
    func onBackspaceClick() {
        guard !isProcessing, !passcode.isEmpty else { return }
        passcode.removeLast()
    }
    
    private func checkPasscode() {
        // Delay 200 ms
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            
            let (storedHash, salt) = self.repository.getPasscodeHashAndSalt()
            
            guard let storedHash, let salt else {
                self.isProcessing = false
                return
            }
            
            self.repository.hashPasscode(passcode: self.passcode, salt: salt).sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Hashing error: \(error)")
                        self.triggerShakeAnimation()
                        self.passcode = ""
                    }
                },
                receiveValue: { newHash in
                    
                    // Compare hashes in constant time
                    if storedHash == newHash {
                        self.passcodeSuccess()
                    } else {
                        self.triggerShakeAnimation()
                    }
                }
            ).store(in: &self.cancellable)
            
        }
    }
    
    private func passcodeSuccess() {
        DispatchQueue.main.async {
            self.isProcessing = false
            self.passcode = ""
            self.onComplete() // Notify UI about success
        }
    }
    
    private func resetState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
            self.passcode = ""
        }
    }
    
    private func triggerShakeAnimation() {
        DispatchQueue.main.async {
            self.shouldShake = true
        }
    }
    
    func onAnimationCompleted() {
        DispatchQueue.main.async {
            self.shouldShake = false
            self.resetState()
        }
    }
    
}

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

class PasscodeSetupViewModel : StoreViewModel<PasscodeSetupState, PasscodeSetupAction> {
    
    typealias State = PasscodeSetupState
    typealias Action = PasscodeSetupAction
    
    private let appConfig: AppConfig
    private let repository: PasscodeRepository
    private var cancellable = Set<AnyCancellable>()
    
    // Published properties for state binding
    @Published var passcode: String = ""
    private var confirmPasscode: String = ""
    @Published var isConfirming: Bool = false
    @Published var isProcessing: Bool = false
    @Published var shouldShake: Bool = false
    
    
    
    init(
        config: AppConfig = .default,
        repository: PasscodeRepository = PasscodeRepository()
    ) {
        self.appConfig = config
        self.repository = repository
        super.init(initialState: PasscodeSetupState(passcodeLength: config.passcodeLength))
        
        self.store.set(reducer: reduce)
        self.store.set(effects: effects)
    }
    
    private func reduce(state: State, action: Action) -> PasscodeSetupState? {
        return nil
    }
    
    // applies side effects to store state and returns a value to keep in scope
    private func effects(state: PasscodeSetupState, action: PasscodeSetupAction) -> Scoped? {
        switch action {
            
        case .OnNumberClick(let number):
            break
        case .OnBackspaceClick:
            break
        case .ProcessPasscodeEntry:
            break
        case .PasscodeSetSuccess:
            break
        case .PasscodeDoNotMatch:
            break
        case .OnComplete:
            store.notify(.OnComplete)
        }
        return nil
    }
    
    
    func onNumberClick(number: String) {
        
        guard !isProcessing, passcode.count < appConfig.passcodeLength else {
            return
        }
        
        passcode += number
        
        if passcode.count == appConfig.passcodeLength {
            isProcessing = true
            processPasscodeEntry()
        }
    }
    
    func onBackspaceClick() {
        guard !isProcessing, !passcode.isEmpty else {
            return
        }
        passcode.removeLast()
    }
    
    
    private func processPasscodeEntry() {
        
        if !isConfirming {
            
            // delay 500ms
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
                // send event to ui (Passcode do not match
                self.triggerShakeAnimation()
            }
        }
    }
    
    private func hashPasscode() {
        // hash passcode
        
        let salt = repository.generateSalt()
        
        repository.hashPasscode(passcode: passcode, salt: salt)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Hashing error: \(error)")
                    }
                    self.triggerShakeAnimation()
                }, receiveValue: { hash in
                    self.repository.storePasscodeHashAndSalt(hash: hash, salt: salt)
                    print("Hashed passcode: \(hash)")
                    // send event to ui (Passcode set)
                    self.store.dispatcher.dispatch(.OnComplete)
                })
            .store(in: &cancellable)
    }
    
    private func resetState() {
        passcode = ""
        confirmPasscode = ""
        isConfirming = false
        isProcessing = false
        shouldShake = false
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

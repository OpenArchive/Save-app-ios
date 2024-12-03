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

// create a AppConfig data class to store config constants
struct AppConfig {
    let passcodeLength: Int = 6
}

class PasscodeSetupViewModel : StoreViewModel<PasscodeSetupState, PasscodeSetupAction> {
    
    typealias State = PasscodeSetupState
    typealias Action = PasscodeSetupAction
    
    // Published properties for state binding
    @Published var passcode: String = ""
    var confirmPasscode: String = ""
    @Published var isConfirming: Bool = false
    @Published var isProcessing: Bool = false
    @Published var shouldShake: Bool = false
    
    let appConfig: AppConfig
    
    init(config: AppConfig = AppConfig()) {
        self.appConfig = config
        super.init(initialState: PasscodeSetupState(passcodeLength: config.passcodeLength))
        
        self.store.set(reducer: reduce)
        self.store.set(effects: effect)
    }
    
    private func reduce(state: State, action: Action) -> State? {
        return nil
    }
    
    private func effect(state: State, action: Action) -> Scoped? {
        return nil
    }
    

    func onNumberClick(number: String) {
            
        guard !isProcessing, passcode.count < appConfig.passcodeLength else {
            return
        }
        
        passcode += number
        
        if passcode.count == appConfig.passcodeLength {
            isProcessing = true
            ProcessPasscodeEntry()
        }
    }
    
    func onBackspaceClick() {
        guard !isProcessing, !passcode.isEmpty else {
            return
        }
        
        passcode.removeLast()
    }
    
 
    private func ProcessPasscodeEntry() {
        
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
                // hash passcode
                // send event to ui (Passcode set)
            } else {
                // send event to ui (Passcode do not match
                shouldShake = true
                //delay(500ms)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.reset()
                }
            }
        }
    }
    
    private func reset() {
        passcode = ""
        confirmPasscode = ""
        isConfirming = false
        isProcessing = false
        shouldShake = false
    }
}

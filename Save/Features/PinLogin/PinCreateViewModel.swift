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

class PinCreateViewModel : StoreViewModel<PinCreateState, PinCreateAction> {
    typealias Action = PinCreateAction
    typealias State = PinCreateState
    
    init() {
        super.init(initialState: PinCreateState())
        self.store.set(reducer: self.reduce)
        self.store.set(effects: self.effects)
    }
    
    func state() -> State.Bindings {
        State.Bindings(
            pin: self.store.bind(\.pin) { .UpdatePin($0) },
            verifyPin: self.store.bind(\.verifyPin) { .UpdateVerifyPin($0) },
            isValid: self.store.dispatcher.state.isValid,
            isPinError: self.store.dispatcher.state.isPinError,
            isBusy: self.store.dispatcher.state.isBusy,
            pinErrorMessage: self.store.dispatcher.state.pinErrorMessage)
    }
    
 
    private func reduce(state: PinCreateState, action: Action) -> PinCreateState? {
        switch action {
        case .UpdatePin(let value):
            let isValid = (value.count == state.verifyPin.count) && validatePin(value, state.verifyPin)
            return state.copy(
                pin: value,
                isValid: isValid,
                isPinError: !isValid && !state.verifyPin.isEmpty,
                pinErrorMessage: !isValid && (value.count == state.verifyPin.count) ? "Pins do not match" : nil
            )

        case .UpdateVerifyPin(let value):
            let isValid = (value.count == state.pin.count) && validatePin(state.pin, value)
            return state.copy(
                verifyPin: value,
                isValid: isValid,
                isPinError: !isValid && !state.pin.isEmpty,
                pinErrorMessage: !isValid && (value.count == state.pin.count) ? "Pins do not match" : nil
            )
        case .SetPin:
            return state.copy(isPinError: false, isBusy: true)
        case .PinSetError:
            return state.copy(isPinError: true, isBusy: false, pinErrorMessage: "Failed to set PIN")
        case .PinSetSuccess:
            return state.copy(isPinError: false,isBusy: false,  pinErrorMessage: nil)
        case .UpdatePinErrorMessage(let message):
            return state.copy(pinErrorMessage: message)
        default:
            return nil
        }
    }
    
    
    private func validatePin(_ pin: String, _ verifyPin: String) -> Bool {
        // Check if the verification PIN is empty or matches the entered PIN
        if verifyPin.isEmpty {
            return true
        }
        return pin == verifyPin
    }
    
    // applies side effects to store state and returns a value to keep in scope
    private func effects(state: PinCreateState, action: Action) -> Scoped? {
        switch action {
        case .SetPin:
            if state.pin.count != 6 {
                self.store.dispatch(.PinSetError)
                self.store.dispatch(.UpdatePinErrorMessage("PIN must be exactly 6 digits"))
                return nil
            }
            if state.pin != state.verifyPin {
                self.store.dispatch(.PinSetError)
                self.store.dispatch(.UpdatePinErrorMessage("Pins do not match"))
                return nil
            }
            
            print("setpin")
            let status = storeAppPin(state.pin)
            if !status {
                self.store.dispatch(.PinSetError)
                self.store.dispatch(.UpdatePinErrorMessage("Failed to set PIN"))
                return nil
            }
            
            self.store.dispatch(.PinSetSuccess)
        case .PinSetSuccess:
            self.store.notify(.Next)
        case .Cancel:
            self.store.notify(.Cancel)
        default: break
        }
        
        return nil
    }
    private func storeAppPin(_ pin: String) -> Bool {
        guard let key = SecureEnclave.createKey(),
              let publicKey = SecureEnclave.getPublicKey(key) else {
            print("Error creating or loading keys.")
            return false
        }
        
        guard let encryptedPin = SecureEnclave.encrypt(pin, with: publicKey) else {
            print("Error encrypting PIN.")
            return false
        }
        UserDefaults.standard.set(encryptedPin, forKey: Keys.encryptedAppPin)
        return true
    }
}

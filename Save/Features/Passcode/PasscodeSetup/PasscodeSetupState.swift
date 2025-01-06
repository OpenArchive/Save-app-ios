//
//  Untitled.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct PasscodeSetupState {
    private(set) var passcode: String = ""
    private(set) var confirmPasscode: String = ""
    let passcodeLength: Int
    private(set) var isConfirming: Bool = false
    private(set) var isProcessing: Bool = false
    private(set) var shouldShake: Bool = false
    
    func copy(
        passcode: String? = nil,
        confirmPasscode: String? = nil,
        isConfirming: Bool? = nil,
        isProcessing: Bool? = nil,
        shouldShake: Bool? = nil
    ) -> PasscodeSetupState {
        var copy = self
        copy.passcode = passcode ?? self.passcode
        copy.confirmPasscode = confirmPasscode ?? self.confirmPasscode
        copy.isConfirming = isConfirming ?? self.isConfirming
        copy.isProcessing = isProcessing ?? self.isProcessing
        copy.shouldShake = shouldShake ?? self.shouldShake
        return copy
    }
}

enum PasscodeSetupUiEvent {
    case PasscodeSet
    case PasscodeDoNotMatch
    case PasscodeCancelled
}


enum PasscodeSetupAction {
    case OnNumberClick(String)
    case OnBackspaceClick
    case ProcessPasscodeEntry
    case PasscodeSetSuccess
    case PasscodeDoNotMatch
    case OnComplete
}

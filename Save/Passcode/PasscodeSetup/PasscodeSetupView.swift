//
//  PinCreateView.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct PasscodeSetupView: View  {
    
    @ObservedObject var viewModel: PasscodeSetupViewModel
    
    var body: some View {
        
        PasscodeSetupContent(
            passcodeLength: viewModel.passcodeLength,
            passcode: viewModel.passcode,
            isConfirming: viewModel.isConfirming,
            isProcessing: viewModel.isProcessing,
            shouldShake: viewModel.shouldShake,
            showPasscodeError: viewModel.showPasswordMismatch,
            onNumberClick: viewModel.onNumberClick,
            onBackspaceClick: viewModel.onBackspaceClick,
            onEnterClick: viewModel.onEnterClick,
            onExit: viewModel.cancel,
            onAnimationCompleted: viewModel.onAnimationCompleted
        )
    }
}

struct PasscodeSetupContent: View {

    let passcodeLength: Int
    let passcode: String
    let isConfirming: Bool
    let isProcessing: Bool
    let shouldShake: Bool
    let showPasscodeError: Bool
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    let onEnterClick: () -> Void
    let onExit: () -> Void
    let onAnimationCompleted: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        PasscodeContentWrapper(
            title: isConfirming ? NSLocalizedString("Confirm Passcode", comment: "Confirm Passcode") : NSLocalizedString("Set Passcode", comment: "Set Passcode"),
            subtitle: NSLocalizedString("Make sure you remember this pin. If you forget it, you will need to reset the app, and all in-app data will be erased.", comment: "subtitle"),
            passcode: passcode,
            passcodeLength: passcodeLength,
            shouldShake: shouldShake,
            isEnabled: !isProcessing,
            isPasscodeEntry: false,
            showPasswordMismatch: showPasscodeError,
            onNumberClick: onNumberClick,
            onBackspaceClick: onBackspaceClick,
            onEnterClick: onEnterClick,
            onExit: onExit,
            onAnimationCompleted: onAnimationCompleted
        )
    }
}




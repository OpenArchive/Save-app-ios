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
            state: viewModel.store.dispatcher.state,
            dispatch: viewModel.store.dispatch,
            passcode: viewModel.passcode,
            isConfirming: viewModel.isConfirming,
            isProcessing: viewModel.isProcessing,
            shouldShake: viewModel.shouldShake,
            onNumberClick: viewModel.onNumberClick,
            onBackspaceClick: viewModel.onBackspaceClick,
            onAnimationCompleted: viewModel.onAnimationCompleted
        )
    }
}

struct PasscodeSetupContent: View {
    
    let state: PasscodeSetupState
    let dispatch: Dispatch<PasscodeSetupAction>
    
    let passcode: String
    
    let isConfirming: Bool
    let isProcessing: Bool
    let shouldShake: Bool
    
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    
    let onAnimationCompleted: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        PasscodeContentWrapper(
            title: isConfirming ? NSLocalizedString("Confirm Passcode",comment: "Confirm Passcode")  : NSLocalizedString("Enter Passcode",comment: "Enter Passcode"),
            passcode: passcode,
            passcodeLength: state.passcodeLength,
            shouldShake: shouldShake,
            isEnabled: !isProcessing,
            onNumberClick: onNumberClick,
            onBackspaceClick: onBackspaceClick,
            onExit: {
                dispatch(.OnComplete)
            },
            onAnimationCompleted: onAnimationCompleted
        )
    }
    
}




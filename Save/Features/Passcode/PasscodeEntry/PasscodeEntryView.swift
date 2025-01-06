import SwiftUI

struct PasscodeEntryView: View {
    
    @ObservedObject private var viewModel: PasscodeEntryViewModel
    
    init(
        onPasscodeSuccess: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        self.viewModel = PasscodeEntryViewModel(onComplete: onPasscodeSuccess)
        self.onExit = onExit
    }
    
    private let onExit: () -> Void
    
    var body: some View {
        
        PasscodeEntryContent(
            passcode: viewModel.passcode,
            passcodeLength: viewModel.passcodeLength,
            isProcessing: viewModel.isProcessing,
            shouldShake: viewModel.shouldShake,
            onNumberClick: { number in
                viewModel.onNumberClick(number)
            },
            onBackspaceClick: {
                viewModel.onBackspaceClick()
            },
            onExit: onExit,
            onAnimationCompleted: viewModel.onAnimationCompleted
        )
    }
}

struct PasscodeEntryContent: View {
    
    let passcode: String
    let passcodeLength: Int
    let isProcessing: Bool
    let shouldShake: Bool
    
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    let onExit: () -> Void
    
    let onAnimationCompleted: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        PasscodeContentWrapper(
            title: "Enter Passcode",
            passcode: passcode,
            passcodeLength: passcodeLength,
            shouldShake: shouldShake,
            isEnabled: !isProcessing,
            onNumberClick: onNumberClick,
            onBackspaceClick: onBackspaceClick,
            onExit: onExit,
            onAnimationCompleted: onAnimationCompleted
        )
        
    }
}



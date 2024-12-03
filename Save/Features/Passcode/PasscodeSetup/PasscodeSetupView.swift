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
            passcodeLength: viewModel.appConfig.passcodeLength,
            isConfirming: viewModel.isConfirming,
            isProcessing: viewModel.isProcessing,
            shouldShake: viewModel.shouldShake,
            onNumberClick: { number in
                viewModel.onNumberClick(number: number)
            },
            onBackspaceClick: {
                viewModel.onBackspaceClick()
            },
            onCancel: {
                //viewModel.store.dispatch(.OnComplete)
            }
        )
    }
}

struct PasscodeSetupContent: View {
    
    let state: PasscodeSetupState
    let dispatch: Dispatch<PasscodeSetupAction>
    
    let passcode: String
    let passcodeLength: Int
    let isConfirming: Bool
    let isProcessing: Bool
    let shouldShake: Bool
    
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack(alignment: .center) {
            
            
            // Logo
            
            PasscodeDots(
                passcodeLength: passcodeLength,
                currentPasscodeLength: passcode.count,
                shouldShake: shouldShake
            )
            
            VStack(spacing: 15) {
                NumericKeypad(
                    isEnabled: true,
                    onNumberClick: { number in
                        onNumberClick(number)
                    }
                )
            }
            .padding()
            
            Spacer()
            
            HStack(alignment: .bottom) {
                
                Button(action: {
                    dispatch(.OnComplete)
                }, label: {
                    Text(LocalizedStringKey("Cancel"))
                }).padding().frame(maxWidth: .infinity).foregroundColor(.accent)
                
                Button(action: {
                    onBackspaceClick()
                }, label: {
                    Text(LocalizedStringKey("Delete"))
                }).padding().frame(maxWidth: .infinity).foregroundColor(.accent)
            
            }.padding()
        }.padding()
    }
    
}


struct SecureNumberPadField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.isSecureTextEntry = true // Mask the input
        textField.keyboardType = .numberPad
        textField.delegate = context.coordinator
        
        // Add padding inside the text field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0)) // Adjust the width for more or less padding
        textField.leftView = paddingView
        textField.leftViewMode = .always

        // Add "Done" button to toolbar
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(textField.resignFirstResponder))
        toolbar.items = [doneButton]
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SecureNumberPadField

        init(_ parent: SecureNumberPadField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.text = textField.text ?? ""
            }
        }
    }
}

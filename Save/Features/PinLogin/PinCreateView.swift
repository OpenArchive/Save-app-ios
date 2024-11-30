//
//  PinCreateView.swift
//  Save
//
//  Created by navoda on 2024-11-29.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct PinCreateView: View  {
    
    @ObservedObject var viewModel: PinCreateViewModel
    
    var body: some View {
        PinCreateContent(
            state: viewModel.state(),
            dispatch: viewModel.store.dispatch
        )
    }
}

struct PinCreateContent: View {
    
    let state: PinCreateState.Bindings
    let dispatch: Dispatch<PinCreateAction>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        VStack(alignment: .center) {
            
            
            SecureNumberPadField(text: state.pin, placeholder: "Enter Passcode")
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .frame(height: 50)
                .padding(.horizontal)
            SecureNumberPadField(text: state.verifyPin, placeholder: "Confirm Passcode")
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .frame(height: 50)
                .padding(.horizontal)
            
            if state.isPinError {
                Text(LocalizedStringKey(state.pinErrorMessage))
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Button(action: {
                    dispatch(.Cancel)
                }, label: {
                    Text(LocalizedStringKey("Cancel"))
                }).padding().frame(maxWidth: .infinity).foregroundColor(.accent)
                
                Button(action: {
                    dispatch(.SetPin)
                }, label: {
                    
                    if (state.isBusy) {
                        ActivityIndicator(style: .medium, animate: .constant(true)).foregroundColor(.black)
                    } else {
                        Text(LocalizedStringKey("Set Pin"))
                    }
                })
                .disabled(!state.isValid)
                .padding()
                .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                .background(Color.accent)
                .foregroundColor(.black)
                .cornerRadius(12)
            }.padding()
        }.padding()
    }
    
}

struct PinCreateView_Previews: PreviewProvider {
    static let state = PinCreateState(
        pin: "",
        verifyPin: "",
        isValid: true,
        isPinError: true,
        isBusy: false,
        pinErrorMessage: ""
    )
    
    static var previews: some View {
        PinCreateContent(
            state: PinCreateState.Bindings(
                pin: Binding.constant(state.pin),
                verifyPin: Binding.constant(state.verifyPin),
                isValid: state.isValid,
                isPinError: state.isPinError,
                isBusy: state.isBusy, pinErrorMessage: state.pinErrorMessage
            )
        ) { _ in }
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

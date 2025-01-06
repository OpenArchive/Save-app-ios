//
//  SecureNumberPadField.swift
//  Save
//
//  Created by Elelan on 2024/12/5.
//  Copyright © 2024 Open Archive. All rights reserved.
//


import SwiftUI

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
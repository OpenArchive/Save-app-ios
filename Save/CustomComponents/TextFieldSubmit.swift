//
//  TextFieldSubmit.swift
//  Save
//
//  Created by navoda on 2026-04-30.
//  Copyright © 2026 Open Archive. All rights reserved.
//


//
//  CustomSubmitModifier.swift
//  Save
//
//  Fixes SwiftUI keyboard flicker when moving focus via Return key.
//  Uses Introspect to attach a UITextField delegate that returns false
//  from textFieldShouldReturn, preventing the default resign + keyboard dismiss.
//

import SwiftUI
import SwiftUIIntrospect

fileprivate struct TextFieldSubmit: ViewModifier {

    private class TextFieldKeyboardBehavior: UIView, UITextFieldDelegate {
        var submitAction: (() -> Void)?
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            submitAction?()
            return false
        }
    }
    
    private var keyboardBehavior = TextFieldKeyboardBehavior()
    
    init(submitAction: @escaping () -> Void) {
        self.keyboardBehavior.submitAction = submitAction
    }
    
    func body(content: Content) -> some View {
        content.introspect(.textField, on: .iOS(.v15, .v16, .v17, .v18, .v26)) { textField in
            textField.delegate = keyboardBehavior
        }
    }
}

fileprivate struct SecureFieldSubmit: ViewModifier {

    private class TextFieldKeyboardBehavior: UIView, UITextFieldDelegate {
        var submitAction: (() -> Void)?
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            submitAction?()
            return false
        }
    }
    
    private var keyboardBehavior = TextFieldKeyboardBehavior()
    
    init(submitAction: @escaping () -> Void) {
        self.keyboardBehavior.submitAction = submitAction
    }
    
    func body(content: Content) -> some View {
        content.introspect(.secureField, on: .iOS(.v15, .v16, .v17, .v18, .v26)) { textField in
            textField.delegate = keyboardBehavior
        }
    }
}

extension TextField {
    func customSubmit(_ submitAction: @escaping () -> Void) -> some View {
        self.modifier(TextFieldSubmit(submitAction: submitAction))
    }
}

extension SecureField {
    func customSubmit(_ submitAction: @escaping () -> Void) -> some View {
        self.modifier(SecureFieldSubmit(submitAction: submitAction))
    }
}
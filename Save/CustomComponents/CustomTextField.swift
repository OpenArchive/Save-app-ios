//
//  CustomTextField.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var keyboardType: UIKeyboardType = .default
    var hasError: Bool = false
    var onEditingChanged: ((Bool) -> Void)? = nil
    var onTextChanged: ((String) -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    
    @State private var isFocused: Bool = false
   
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .italic()
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(.textEmpty)
                    .padding(.leading, 16)
            }

            if isSecure {
                SecureField("", text: $text)
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            } else {
                if #available(iOS 14.0, *) {
                    TextField("", text: $text, onEditingChanged: { began in
                        isFocused = began
                        onEditingChanged?(began)
                    }, onCommit: {
                        onCommit?()
                    })
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled()
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .font(.montserrat(.medium, for: .footnote))
                        .padding(12)
                }
            }
        }
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor(), lineWidth: hasError ? 2 : 1)
        )
        .background(isDisabled ? Color.gray.opacity(0.2) : Color.textboxBg)
        .disabled(isDisabled)
        .padding(.bottom, 8)
    }
    
    private func borderColor() -> Color {
        if hasError {
            return .red
        } else if isFocused {
            return .accent
        } else {
            return .gray70
        }
    }
}

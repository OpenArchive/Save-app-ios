//
//  CustomTextField.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var isError: Bool = false
    var onEditingChanged: ((Bool) -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onCommit: (() -> Void)?

    @State private var isFocused = false

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
                TextField("", text: $text, onEditingChanged: handleEditingChanged, onCommit: { onCommit?() })
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            }
        }
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .background(isDisabled ? Color.gray.opacity(0.2) : Color.textboxBg)
        .disabled(isDisabled)
        .padding(.bottom, 8)
    }

    private func handleEditingChanged(_ began: Bool) {
        isFocused = began
        onEditingChanged?(began)
    }

    private var borderColor: Color {
        if isError { return .redButton }
        if isFocused { return .accent }
        return .gray70
    }
}

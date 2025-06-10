//
//  CustomTextField.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var onEditingChanged: (() -> Void)? = nil
    var onCommit: (() -> Void)? = nil
    
    
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
                    TextField("", text: $text, onEditingChanged: { _ in
                        onEditingChanged?()
                    }, onCommit: {
                        onCommit?()
                    })
                    .onChange(of: text) { _ in
                        onEditingChanged?()
                    }
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
                } else {
                    // Add fallback logic if needed
                    TextField("", text: $text)
                        .font(.montserrat(.medium, for: .footnote))
                        .padding(12)
                }
            }
        }
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.7)))
        .background(isDisabled ? Color.gray.opacity(0.2) : Color.textboxBg)
        .disabled(isDisabled)
        .padding(.bottom, 8)
    }
    
}

//
//  CustomTextField.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

/// Default generic parameter when `CustomTextField` is used without `@FocusState` wiring.
enum CustomTextFieldNoFocus: Hashable {
    case unused
}

struct CustomTextField<FocusValue: Hashable>: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var isError: Bool = false
    var onEditingChanged: ((Bool) -> Void)?
    var onTextChanged: ((String) -> Void)?
    var onCommit: (() -> Void)?
    /// When set with `focusEquals`, binds this field to the parent `@FocusState` for Return-key navigation.
    var focusBinding: FocusState<FocusValue?>.Binding? = nil
    var focusEquals: FocusValue? = nil
    /// Pass the parent's current `focusedField` so the border tracks `@FocusState`.
    var currentFocus: FocusValue? = nil
    var submitLabel: SubmitLabel? = nil

    @FocusState private var localFocusActive: Bool

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
                focusedSecureField
            } else {
                focusedTextField
            }
        }
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .background(isDisabled ? Color.gray.opacity(0.2) : Color.textboxBg)
        .disabled(isDisabled)
        .padding(.bottom, 8)
    }

    private var borderColor: Color {
        if isError { return .redButton }
        if showsAccentBorder { return .accent }
        return .gray70
    }

    private var showsAccentBorder: Bool {
        if focusBinding != nil, let fv = focusEquals, let current = currentFocus {
            return current == fv
        }
        return localFocusActive
    }

    @ViewBuilder
    private var focusedTextField: some View {
        if let binding = focusBinding, let fv = focusEquals {
            applySubmitLabel(to:
                TextField("", text: $text)
                    .customSubmit { onCommit?() }
                    .focused(binding, equals: fv)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            )
            .onChange(of: currentFocus) { newFocus in
                onEditingChanged?(newFocus == fv)
            }
        } else {
            applySubmitLabel(to:
                TextField("", text: $text)
                    .customSubmit { onCommit?() }
                    .focused($localFocusActive)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            )
            .onChange(of: localFocusActive) { isActive in
                onEditingChanged?(isActive)
            }
        }
    }

    @ViewBuilder
    private var focusedSecureField: some View {
        if let binding = focusBinding, let fv = focusEquals {
            applySubmitLabel(to:
                SecureField("", text: $text)
                    .customSubmit { onCommit?() }
                    .focused(binding, equals: fv)
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            )
            .onChange(of: currentFocus) { newFocus in
                onEditingChanged?(newFocus == fv)
            }
        } else {
            applySubmitLabel(to:
                SecureField("", text: $text)
                    .customSubmit { onCommit?() }
                    .focused($localFocusActive)
                    .font(.montserrat(.medium, for: .footnote))
                    .padding(12)
            )
            .onChange(of: localFocusActive) { isActive in
                onEditingChanged?(isActive)
            }
        }
    }

    @ViewBuilder
    private func applySubmitLabel<F: View>(to content: F) -> some View {
        if let label = submitLabel {
            content.submitLabel(label)
        } else {
            content
        }
    }
}

extension CustomTextField where FocusValue == CustomTextFieldNoFocus {
    init(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        isDisabled: Bool = false,
        isError: Bool = false,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onTextChanged: ((String) -> Void)? = nil,
        onCommit: (() -> Void)? = nil,
        submitLabel: SubmitLabel? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.isDisabled = isDisabled
        self.isError = isError
        self.onEditingChanged = onEditingChanged
        self.onTextChanged = onTextChanged
        self.onCommit = onCommit
        self.focusBinding = nil
        self.focusEquals = nil
        self.currentFocus = nil
        self.submitLabel = submitLabel
    }
}

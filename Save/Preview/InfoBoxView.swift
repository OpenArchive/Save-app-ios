//
//  InfoBoxView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

struct InfoBoxView: View {
    let iconName: String
    let placeholder: String
    @Binding var text: String
    var hideIcon: Bool = true
    var isMultiline: Bool = false
    var onTextChanged: ((String) -> Void)?
    /// When set with `mediaField`, coordinates focus with `MediaInfoSectionView` / parent `@FocusState`.
    var mediaFocusBinding: FocusState<MediaInfoField?>.Binding?
    var mediaField: MediaInfoField?
    /// Return key: e.g. move to next field or dismiss keyboard (used with `customSubmit` to avoid keyboard flicker).
    var onSubmitFromKeyboard: (() -> Void)?

    @FocusState private var localFocused: Bool

    init(
        iconName: String,
        placeholder: String,
        text: Binding<String>,
        hideIcon: Bool = true,
        isMultiline: Bool = false,
        onTextChanged: ((String) -> Void)? = nil,
        mediaFocusBinding: FocusState<MediaInfoField?>.Binding? = nil,
        mediaField: MediaInfoField? = nil,
        onSubmitFromKeyboard: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.placeholder = placeholder
        self._text = text
        self.hideIcon = hideIcon
        self.isMultiline = isMultiline
        self.onTextChanged = onTextChanged
        self.mediaFocusBinding = mediaFocusBinding
        self.mediaField = mediaField
        self.onSubmitFromKeyboard = onSubmitFromKeyboard
    }

    private var placeholderFont: Font {
        .montserrat(.mediumItalic, for: .footnote)
    }

    private var isFieldFocused: Bool {
        if let binding = mediaFocusBinding, let field = mediaField {
            return binding.wrappedValue == field
        }
        return localFocused
    }

    private var borderColor: Color {
        isFieldFocused ? Color.accentColor : .gray70
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !hideIcon {
                Image(iconName)
                    .renderingMode(text.isEmpty ? .original : .template)
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
            }
            
            if isMultiline {
                multilineTextField
            } else {
                singleLineTextField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(UIColor.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var singleLineTextField: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty && !isFieldFocused {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundColor(.gray70)
                    .allowsHitTesting(false)
            }
            if let binding = mediaFocusBinding, let field = mediaField {
                TextField("", text: $text)
                    .customSubmit { onSubmitFromKeyboard?() }
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(Color(.label))
                    .focused(binding, equals: field)
                    .submitLabel(.next)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
            } else {
                TextField("", text: $text)
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(Color(.label))
                    .focused($localFocused)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var multilineTextField: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !isFieldFocused {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundColor(.gray70)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }

            if #available(iOS 16.0, *) {
                if let binding = mediaFocusBinding, let field = mediaField {
                    TextField("", text: $text, axis: .vertical)
                        .customSubmit { onSubmitFromKeyboard?() }
                        .font(.montserrat(.medium, for: .footnote))
                        .foregroundColor(Color(.label))
                        .focused(binding, equals: field)
                        .submitLabel(.done)
                        .onChange(of: text) { newValue in
                            onTextChanged?(newValue)
                        }
                        .lineLimit(4...8)
                        .frame(minHeight: 80, alignment: .topLeading)
                } else {
                    TextField("", text: $text, axis: .vertical)
                        .font(.montserrat(.medium, for: .footnote))
                        .foregroundColor(Color(.label))
                        .focused($localFocused)
                        .onChange(of: text) { newValue in
                            onTextChanged?(newValue)
                        }
                        .lineLimit(4...8)
                        .frame(minHeight: 80, alignment: .topLeading)
                }
            } else {
                if let binding = mediaFocusBinding, let field = mediaField {
                    TextEditor(text: $text)
                        .font(.montserrat(.medium, for: .footnote))
                        .foregroundColor(Color(.label))
                        .focused(binding, equals: field)
                        .onChange(of: text) { newValue in
                            onTextChanged?(newValue)
                        }
                        .frame(minHeight: 80)
                } else {
                    TextEditor(text: $text)
                        .font(.montserrat(.medium, for: .footnote))
                        .foregroundColor(Color(.label))
                        .focused($localFocused)
                        .onChange(of: text) { newValue in
                            onTextChanged?(newValue)
                        }
                        .frame(minHeight: 80)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FlagView: View {
    @Binding var isSelected: Bool
    var unselectedColor: Color = Color(.label)
    var size: CGFloat = 20
    var onTap: (() -> Void)?
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            Image(systemName: isSelected ? "flag.fill" : "flag")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(isSelected ? .yellow : unselectedColor)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

#if DEBUG
struct InfoBoxView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            InfoBoxView(
                iconName: "ic_location",
                placeholder: "Add a location (optional)",
                text: .constant(""),
                isMultiline: false
            )
            
            InfoBoxView(
                iconName: "ic_edit",
                placeholder: "Add notes (optional)",
                text: .constant(""),
                isMultiline: true
            )
            
            InfoBoxView(
                iconName: "ic_edit",
                placeholder: "Add notes (optional)",
                text: .constant("Some notes here"),
                isMultiline: true
            )
            
            HStack {
                Text("Flag:")
                FlagView(isSelected: .constant(false))
                FlagView(isSelected: .constant(true))
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
#endif

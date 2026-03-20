//
//  InfoBoxView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct InfoBoxView: View {
    let iconName: String
    let placeholder: String
    @Binding var text: String
    var hideIcon: Bool = true
    var isMultiline: Bool = false
    var onTextChanged: ((String) -> Void)?
    
    @FocusState private var isFocused: Bool
    
    private var placeholderFont: Font {
        .montserrat(.mediumItalic, for: .footnote)
    }
    
    private var borderColor: Color {
        isFocused ? Color.accentColor : .gray70
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
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundColor(.gray70)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .font(.montserrat(.medium, for: .footnote))
                .foregroundColor(Color(.label))
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    onTextChanged?(newValue)
                }
        }
    }
    
    @ViewBuilder
    private var multilineTextField: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundColor(.gray70)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            
            if #available(iOS 16.0, *) {
                TextField("", text: $text, axis: .vertical)
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(Color(.label))
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .lineLimit(4...8)
                    .frame(minHeight: 80, alignment: .topLeading)
            } else {
                TextEditor(text: $text)
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(Color(.label))
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        onTextChanged?(newValue)
                    }
                    .frame(minHeight: 80)
            }
        }
    }
}

struct FlagView: View {
    @Binding var isSelected: Bool
    var unselectedColor: Color = Color(.label)
    var size: CGFloat = 20
    var onTap: (() -> Void)?
    
    private var flagColor: Color {
        isSelected ? Color("Warning") : unselectedColor
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            Image("ic_flag")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(flagColor)
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

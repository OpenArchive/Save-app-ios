
//
//  MediaInfoSectionView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

struct MediaInfoSectionView: View {
    @Binding var location: String
    @Binding var notes: String
    var focusedField: FocusState<MediaInfoField?>.Binding
    var onLocationChanged: (String) -> Void
    var onNotesChanged: (String) -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .bottom)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        InfoBoxView(
                            iconName: "ic_location",
                            placeholder: NSLocalizedString("Add a location (optional)", comment: ""),
                            text: $location,
                            isMultiline: false,
                            onTextChanged: onLocationChanged,
                            mediaFocusBinding: focusedField,
                            mediaField: .location,
                            onSubmitFromKeyboard: {
                                focusedField.wrappedValue = .notes
                            }
                        )

                        InfoBoxView(
                            iconName: "ic_edit",
                            placeholder: NSLocalizedString("Add notes (optional)", comment: ""),
                            text: $notes,
                            isMultiline: true,
                            onTextChanged: onNotesChanged,
                            mediaFocusBinding: focusedField,
                            mediaField: .notes,
                            onSubmitFromKeyboard: {
                                focusedField.wrappedValue = nil
                                UIApplication.shared.endEditing()
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField.wrappedValue = nil
                        UIApplication.shared.endEditing()
                    }
                }
                .modifier(ScrollDismissesKeyboardModifier())
            }
        }
    }
}

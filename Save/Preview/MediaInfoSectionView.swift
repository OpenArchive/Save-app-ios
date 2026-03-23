
//
//  MediaInfoSectionView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct MediaInfoSectionView: View {
    @Binding var location: String
    @Binding var notes: String
    var focusedField: FocusState<MediaInfoField?>.Binding
    var onLocationChanged: (String) -> Void
    var onNotesChanged: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    InfoBoxView(
                        iconName: "ic_location",
                        placeholder: NSLocalizedString("Add a location (optional)", comment: ""),
                        text: $location,
                        isMultiline: false,
                        onTextChanged: onLocationChanged
                    )
                    .focused(focusedField, equals: .location)

                    InfoBoxView(
                        iconName: "ic_edit",
                        placeholder: NSLocalizedString("Add notes (optional)", comment: ""),
                        text: $notes,
                        isMultiline: true,
                        onTextChanged: onNotesChanged
                    )
                    .focused(focusedField, equals: .notes)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .modifier(ScrollDismissesKeyboardModifier())
        }
        .background(Color(UIColor.systemBackground))
    }
}

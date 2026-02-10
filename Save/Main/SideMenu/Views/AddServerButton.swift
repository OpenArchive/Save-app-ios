//
//  AddServerButton.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct AddServerButton: View {
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        Button(action: {
            coordinator.addSpace()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(UIColor.accent))

                Text(NSLocalizedString("Add new server", comment: ""))
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(Color(UIColor.accent))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.pillBackground))
        .accessibilityIdentifier("cellAddAccount")
    }
}

//
//  StorachaServerButton.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct StorachaServerButton: View {
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        Button(action: {
            coordinator.manageStoracha()
            coordinator.hideMenu()
        }) {
            HStack(spacing: 12) {
                Image("storachaBird")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(UIColor.accent))

                Text(NSLocalizedString("Storacha Service", comment: ""))
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(Color(UIColor.accent))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.pillBackground))
        .accessibilityIdentifier("cellStoracha")
    }
}

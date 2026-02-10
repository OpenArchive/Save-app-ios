//
//  ServerHeaderView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ServerHeaderView: View {
    @EnvironmentObject var viewModel: SideMenuViewModel

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.store(.toggleServersExpanded)
                }
            }) {
                HStack(spacing: 12) {
                    Text(NSLocalizedString("Servers", comment: ""))
                        .font(.montserrat(.semibold, for: .callout))
                        .foregroundColor(Color(UIColor.label))

                    Spacer()

                    Image(systemName: viewModel.store().isServersExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.label))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .accessibilityIdentifier("viewHeader")

            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 1)
        }
    }
}

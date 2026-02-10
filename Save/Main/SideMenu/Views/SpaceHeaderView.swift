//
//  SpaceHeaderView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct SpaceHeaderView: View {
    @EnvironmentObject var viewModel: SideMenuViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(viewModel.store().currentSpaceIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(Color(UIColor.label))

            Text(viewModel.store().currentSpaceName)
                .font(.montserrat(.semibold, for: .callout))
                .foregroundColor(Color(UIColor.label))
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Color(UIColor.systemBackground))
    }
}

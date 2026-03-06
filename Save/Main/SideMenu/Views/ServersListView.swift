//
//  ServersListView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ServersListView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    private var showStoracha: Bool {
        SessionManager.shared.loadSession()?.sessionId != nil
            || (SessionManager.shared.loadSpaceCount() ?? 0) > 0
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.spaces, id: \.id) { space in
                    ServerItemView(space: space, isSelected: space.id == viewModel.selectedSpaceId)
                        .onTapGesture {
                            viewModel.selectSpace(space)
                        }
                }
                if showStoracha {
                    StorachaServerButton()
                }
                AddServerButton()
            }
        }
    }
}

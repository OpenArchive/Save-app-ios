//
//  SideMenuView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        let isMenuVisible = viewModel.isMenuVisible
        ZStack(alignment: .trailing) {
            if isMenuVisible {
                Color.black.opacity(0.45)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { coordinator.hideMenu() }
            }

            VStack(spacing: 0) {
                ServerHeaderView()

                if viewModel.isServersExpanded {
                    ServersListView()
                        .transition(.opacity)
                    Spacer()
                } else {
                    if viewModel.showSpaceHeader {
                        SpaceHeaderView()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    ProjectsListView()
                    Spacer()
                    AddFolderButton()
                }
            }
            .frame(width: HomeState.menuWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(UIColor.systemBackground))
            .offset(x: isMenuVisible ? 0 : HomeState.menuWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(isMenuVisible)
    }
}

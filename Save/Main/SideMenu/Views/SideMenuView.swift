//
//  SideMenuView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject var viewModel: SideMenuViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        ZStack(alignment: .trailing) {
            if viewModel.store().isMenuVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { coordinator.hideMenu() }
            }

            VStack(spacing: 0) {
                ServerHeaderView()

                if viewModel.store().isServersExpanded {
                    ServersListView()
                        .transition(.opacity)
                    Spacer()
                } else {
                    if viewModel.store().showSpaceHeader {
                        SpaceHeaderView()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    ProjectsListView()
                    Spacer()
                    AddFolderButton()
                }
            }
            .frame(width: SideMenuState.menuWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(UIColor.systemBackground))
            .offset(x: viewModel.store().isMenuVisible ? 0 : SideMenuState.menuWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(viewModel.store().isMenuVisible)
        .animation(.easeInOut(duration: 0.25), value: viewModel.store().isMenuVisible)
    }
}

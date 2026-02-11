//
//  ServersListView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ServersListView: View {
    @EnvironmentObject var viewModel: SideMenuViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.store().spaces, id: \.id) { space in
                ServerItemView(space: space, isSelected: space.id == viewModel.store().selectedSpaceId)
                    .onTapGesture {
                        SelectedSpace.space = space
                        SelectedSpace.store()
                        SelectedProject.project = nil
                        SelectedProject.store()

                        viewModel.store(.selectSpace(space.id))

                        // Notify MainViewController to update the space icon
                        NotificationCenter.default.post(name: .spaceUpdated, object: space)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.store(.toggleSpaceHeader(show: true))
                            viewModel.store(.toggleServersExpanded)
                        }
                        coordinator.hideSelectMedia()
                    }
            }
            AddServerButton()
        }
    }
}

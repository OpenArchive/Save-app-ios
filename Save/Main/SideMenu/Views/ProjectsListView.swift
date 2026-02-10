//
//  ProjectsListView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject var viewModel: SideMenuViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.store().projects, id: \.id) { project in
                    ProjectItemView(
                        project: project,
                        isSelected: project.id == viewModel.store().selectedProjectId,
                        isIndented: viewModel.store().showSpaceHeader
                    )
                    .onTapGesture {
                        handleProjectTap(project)
                    }
                }
            }
        }
    }

    private func handleProjectTap(_ project: Project) {
        viewModel.store(.selectProject(project.id))
        SelectedProject.project = project
        SelectedProject.store()
        coordinator.selectedProject(project)
    }
}

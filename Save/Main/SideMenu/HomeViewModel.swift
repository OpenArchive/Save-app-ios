//
//  HomeViewModel.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//
//  Shared by side menu and main media view (spaces, projects, selection).
//  When converting media view to SwiftUI/MVVM, reuse this ViewModel.
//

import Foundation
import SwiftUI
import Combine
import YapDatabase

final class HomeViewModel: ObservableObject {
    let coordinator: NavigationCoordinator
    private var databaseObserver: HomeDatabaseObserver?

    @Published var spaces: [Space] = []
    @Published var projects: [Project] = []
    @Published var selectedSpaceId: String?
    @Published var selectedProjectId: String?
    @Published var isMenuVisible = false
    @Published var isServersExpanded = false
    @Published var showSpaceHeader = false
    @Published var currentSpaceName = ""
    @Published var currentSpaceIcon = ""
    @Published var isAnimating = false

    var selectedProject: Project? {
        get {
            guard let id = selectedProjectId else { return nil }
            return projects.first { $0.id == id }
        }
        set {
            selectedProjectId = newValue?.id
            SelectedProject.project = newValue
            SelectedProject.store()
        }
    }

    init(
        spacesConn: YapDatabaseConnection,
        spacesMappings: YapDatabaseViewMappings,
        projectsConn: YapDatabaseConnection?,
        projectsMappings: YapDatabaseViewMappings?,
        coordinator: NavigationCoordinator
    ) {
        self.coordinator = coordinator

        databaseObserver = HomeDatabaseObserver(
            spacesConn: spacesConn,
            spacesMappings: spacesMappings,
            projectsConn: projectsConn,
            projectsMappings: projectsMappings,
            onFetchComplete: { [weak self] spaces, projects in
                self?.applySpaces(spaces)
                self?.applyProjects(projects)
                self?.reconcileSelection(spaces: spaces, projects: projects)
            }
        )

        databaseObserver?.refresh()
    }

    func applySpaces(_ spaces: [Space]) {
        self.spaces = spaces
        if let currentSpace = SelectedSpace.space, spaces.contains(where: { $0.id == currentSpace.id }) {
            if selectedSpaceId != currentSpace.id {
                selectedSpaceId = currentSpace.id
            }
        }
        if let space = SelectedSpace.space {
            let iconName = space.iconName
            if currentSpaceName != space.prettyName || currentSpaceIcon != iconName {
                currentSpaceName = space.prettyName
                currentSpaceIcon = iconName
                showSpaceHeader = true
            }
        }
    }

    func applyProjects(_ projects: [Project]) {
        self.projects = projects
    }

    func reconcileSelection(spaces: [Space], projects: [Project]) {
        let currentId = selectedProjectId

        // If SelectedProject was set externally (e.g. Add/Browse) and is in the list, prefer it
        if let selectedFromStore = SelectedProject.project,
           selectedFromStore.active,
           projects.contains(where: { $0.id == selectedFromStore.id }),
           selectedProjectId != selectedFromStore.id
        {
            selectedProjectId = selectedFromStore.id
            coordinator.selectedProject(selectedFromStore)
            return
        }

        if let currentId = currentId, projects.contains(where: { $0.id == currentId }) {
            if SelectedProject.project?.id != currentId, let project = projects.first(where: { $0.id == currentId }) {
                SelectedProject.project = project
                SelectedProject.store()
                coordinator.selectedProject(project)
            }
            return
        }

        if let currentId = currentId, !projects.contains(where: { $0.id == currentId }) {
            if let next = projects.first {
                selectedProjectId = next.id
                if SelectedProject.project?.id != next.id {
                    SelectedProject.project = next
                    SelectedProject.store()
                }
                coordinator.selectedProject(next)
            } else {
                selectedProjectId = nil
                if SelectedProject.project != nil {
                    SelectedProject.project = nil
                    SelectedProject.store()
                }
                coordinator.selectedProject(nil)
            }
            return
        }

        if currentId == nil, !projects.isEmpty {
            if let selectedProject = SelectedProject.project,
               selectedProject.spaceId == SelectedSpace.id,
               selectedProject.active,
               projects.contains(where: { $0.id == selectedProject.id }) {
                selectedProjectId = selectedProject.id
                coordinator.selectedProject(selectedProject)
            } else if let first = projects.first {
                selectedProjectId = first.id
                if SelectedProject.project?.id != first.id {
                    SelectedProject.project = first
                    SelectedProject.store()
                }
                coordinator.selectedProject(first)
            }
        }
    }

    func animateMenu(show: Bool, completion: (() -> Void)? = nil) {
        guard !isAnimating else {
            completion?()
            return
        }
        isAnimating = true
        withAnimation(.easeInOut(duration: 0.25)) {
            isMenuVisible = show
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { [weak self] in
            self?.isAnimating = false
            completion?()
        }
    }

    func reload() {
        databaseObserver?.refresh()
    }

    func reloadAndSelect(_ projectId: String) {
        guard let projectsConn = databaseObserver?.projectsConn,
              let projectsMappings = databaseObserver?.projectsMappings else { return }
        projectsConn.update(mappings: projectsMappings)
        let allProjects: [Project] = projectsConn.objects(in: 0, with: projectsMappings)
        let projects = allProjects.filter(\.active)
        applyProjects(projects)
        if projects.contains(where: { $0.id == projectId }) {
            selectedProjectId = projectId
            if let project = projects.first(where: { $0.id == projectId }) {
                SelectedProject.project = project
                SelectedProject.store()
                coordinator.selectedProject(project)
            }
        }
    }

    func selectSpace(_ space: Space) {
        SelectedSpace.space = space
        SelectedSpace.store()
        SelectedProject.project = nil
        SelectedProject.store()
        selectedSpaceId = space.id
        selectedProjectId = nil
        NotificationCenter.default.post(name: .spaceUpdated, object: space)
        withAnimation(.easeInOut(duration: 0.25)) {
            showSpaceHeader = true
            isServersExpanded = false
        }
        currentSpaceName = space.prettyName
        currentSpaceIcon = space.iconName
        coordinator.hideSelectMedia()
    }

    func selectProject(_ project: Project) {
        SelectedProject.project = project
        SelectedProject.store()
        selectedProjectId = project.id
        coordinator.selectedProject(project)
    }

    func toggleServersExpanded() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isServersExpanded.toggle()
        }
    }

    func updateSpace(_ space: Space?) {
        guard let space = space else { return }
        currentSpaceName = space.prettyName
        currentSpaceIcon = space.iconName
        showSpaceHeader = true
    }
}

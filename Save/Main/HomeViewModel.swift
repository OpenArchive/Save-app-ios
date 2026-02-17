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
                self?.reconcileSelection(projects: projects)
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
        } else {
            currentSpaceName = ""
            currentSpaceIcon = ""
            showSpaceHeader = false
        }
    }

    func applyProjects(_ projects: [Project]) {
        self.projects = projects
    }

    func reconcileSelection(projects: [Project]) {
        if syncFromExternalSelectionIfNeeded(projects: projects) { return }
        if syncCurrentSelectionIfNeeded(projects: projects) { return }
        if handleCurrentProjectMissing(projects: projects) { return }
        handleNoSelection(projects: projects)
    }

    /// If SelectedProject was set externally (e.g. Add/Browse) and differs from our state, sync to it.
    private func syncFromExternalSelectionIfNeeded(projects: [Project]) -> Bool {
        guard let selectedFromStore = SelectedProject.project,
              selectedFromStore.active,
              projects.contains(where: { $0.id == selectedFromStore.id }),
              selectedProjectId != selectedFromStore.id else { return false }
        selectedProjectId = selectedFromStore.id
        coordinator.selectedProject(selectedFromStore)
        return true
    }

    /// Current selection is in list; ensure SelectedProject and coordinator are in sync.
    private func syncCurrentSelectionIfNeeded(projects: [Project]) -> Bool {
        guard let currentId = selectedProjectId,
              projects.contains(where: { $0.id == currentId }) else { return false }
        if SelectedProject.project?.id != currentId, let project = projects.first(where: { $0.id == currentId }) {
            SelectedProject.project = project
            SelectedProject.store()
            coordinator.selectedProject(project)
        }
        return true
    }

    /// Current selection was removed (archived/deleted); pick next or clear.
    private func handleCurrentProjectMissing(projects: [Project]) -> Bool {
        guard let currentId = selectedProjectId,
              !projects.contains(where: { $0.id == currentId }) else { return false }
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
        return true
    }

    /// No selection yet; restore from SelectedProject or pick first.
    private func handleNoSelection(projects: [Project]) {
        guard selectedProjectId == nil, !projects.isEmpty else { return }
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
        let projects = databaseObserver?.fetchProjectsSync() ?? []
        applyProjects(projects)
        if projects.contains(where: { $0.id == projectId }),
           let project = projects.first(where: { $0.id == projectId }) {
            selectedProjectId = projectId
            SelectedProject.project = project
            SelectedProject.store()
            coordinator.selectedProject(project)
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

}

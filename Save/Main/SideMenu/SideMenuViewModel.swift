//
//  SideMenuViewModel.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import SwiftUI
import YapDatabase

final class SideMenuViewModel: StoreViewModel<SideMenuState, SideMenuAction> {
    let coordinator: NavigationCoordinator
    private var databaseObserver: SideMenuDatabaseObserver?

    init(
        spacesConn: YapDatabaseConnection,
        spacesMappings: YapDatabaseViewMappings,
        projectsConn: YapDatabaseConnection?,
        projectsMappings: YapDatabaseViewMappings?,
        coordinator: NavigationCoordinator
    ) {
        self.coordinator = coordinator
        super.init(initialState: SideMenuState(), reducer: sideMenuReducer, effects: nil)

        databaseObserver = SideMenuDatabaseObserver(
            spacesConn: spacesConn,
            spacesMappings: spacesMappings,
            projectsConn: projectsConn,
            projectsMappings: projectsMappings,
            store: store,
            coordinator: coordinator
        )

        loadInitialData(spacesConn, spacesMappings, projectsConn, projectsMappings)
    }

    var selectedProject: Project? {
        get {
            guard let id = store().selectedProjectId else { return nil }
            return store().projects.first { $0.id == id }
        }
        set {
            store.dispatch(.selectProject(newValue?.id))
        }
    }

    func animateMenu(show: Bool, completion: (() -> Void)? = nil) {
        guard !store().isAnimating else {
            completion?()
            return
        }

        store.dispatch(.setAnimating(true))
        withAnimation(.easeInOut(duration: 0.25)) {
            store.dispatch(.toggleMenu(show: show))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            self.store.dispatch(.setAnimating(false))
            completion?()
        }
    }

    func reload() {
        databaseObserver?.yapDatabaseModified(notification: .init(name: .YapDatabaseModified))

        if store().selectedProjectId == nil, !store().projects.isEmpty {
            if let selectedProject = SelectedProject.project,
               selectedProject.spaceId == SelectedSpace.id,
               selectedProject.active,
               store().projects.contains(where: { $0.id == selectedProject.id }) {
                store.dispatch(.selectProject(selectedProject.id))
            } else {
                store.dispatch(.selectProject(store().projects[0].id))
            }
        }
    }

    func reloadAndSelect(_ projectId: String) {
        guard let projectsConn = databaseObserver?.projectsConn,
              let projectsMappings = databaseObserver?.projectsMappings else { return }

        projectsConn.update(mappings: projectsMappings)
        let allProjects: [Project] = projectsConn.objects(in: 0, with: projectsMappings)
        let projects = allProjects.filter(\.active)

        store.dispatch(.updateProjects(projects))
        if projects.contains(where: { $0.id == projectId }) {
            store.dispatch(.selectProject(projectId))
        }
    }

    func updateSpace(_ space: Space?) {
        guard let space = space else { return }

        let iconName = space is IaSpace ? "internet_archive" : "private_server"
        store.dispatch(.updateSpaceHeader(name: space.prettyName, iconName: iconName))

        // Don't update spaces list here - the database observer handles that
        // Calling updateSpaceInList here causes a race condition where we read stale data from store
    }

    private func updateSpaceInList(_ updatedSpace: Space) {
        var spaces = store().spaces

        // Find and replace the space in the array
        if let index = spaces.firstIndex(where: { $0.id == updatedSpace.id }) {
            spaces[index] = updatedSpace
        } else {
            // If not found, add it (new space)
            spaces.append(updatedSpace)
        }

        store.dispatch(.updateSpaces(spaces))
        store.dispatch(.selectSpace(updatedSpace.id))
    }

    private func loadInitialData(
        _ spacesConn: YapDatabaseConnection,
        _ spacesMappings: YapDatabaseViewMappings,
        _ projectsConn: YapDatabaseConnection?,
        _ projectsMappings: YapDatabaseViewMappings?
    ) {
        let spaces: [Space] = spacesConn.objects(in: 0, with: spacesMappings)
        DispatchQueue.main.async {
            self.store.dispatch(.updateSpaces(spaces))
            if let currentSpace = SelectedSpace.space, spaces.contains(where: { $0.id == currentSpace.id }) {
                self.store.dispatch(.selectSpace(currentSpace.id))
            }
        }

        guard let projectsConn = projectsConn, let projectsMappings = projectsMappings else { return }
        let allProjects: [Project] = projectsConn.objects(in: 0, with: projectsMappings)
        let projects = allProjects.filter(\.active)

        DispatchQueue.main.async {
            self.store.dispatch(.updateProjects(projects))
            // Don't auto-select here - let viewWillAppear handle it
        }
    }

    private func autoSelectProject(from projects: [Project]) {
        guard !projects.isEmpty else { return }

        // If there's already a valid selection, don't override it
        if let currentId = store().selectedProjectId,
           projects.contains(where: { $0.id == currentId }) {
            return
        }

        // Try to restore previously selected project
        if let selected = SelectedProject.project,
           selected.spaceId == SelectedSpace.id,
           selected.active,
           projects.contains(where: { $0.id == selected.id }) {
            store.dispatch(.selectProject(selected.id))
            return
        }

        // Default to first project
        let first = projects[0]
        store.dispatch(.selectProject(first.id))
        SelectedProject.project = first
        SelectedProject.store()
        coordinator.selectedProject(first)
    }
}

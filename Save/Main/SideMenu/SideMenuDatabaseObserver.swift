//
//  SideMenuDatabaseObserver.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

final class SideMenuDatabaseObserver {
    let spacesConn: YapDatabaseConnection
    let spacesMappings: YapDatabaseViewMappings
    let projectsConn: YapDatabaseConnection?
    let projectsMappings: YapDatabaseViewMappings?
    private let store: StateStore<SideMenuState, SideMenuAction>
    private weak var coordinator: NavigationCoordinator?

    init(
        spacesConn: YapDatabaseConnection,
        spacesMappings: YapDatabaseViewMappings,
        projectsConn: YapDatabaseConnection?,
        projectsMappings: YapDatabaseViewMappings?,
        store: StateStore<SideMenuState, SideMenuAction>,
        coordinator: NavigationCoordinator
    ) {
        self.spacesConn = spacesConn
        self.spacesMappings = spacesMappings
        self.projectsConn = projectsConn
        self.projectsMappings = projectsMappings
        self.store = store
        self.coordinator = coordinator
        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    @objc func yapDatabaseModified(notification: Notification) {
        handleSpacesChanges()
        handleProjectsChanges()
    }

    private func handleSpacesChanges() {
        spacesConn.update(mappings: spacesMappings)
        let changes = spacesConn.getChanges(spacesMappings)
        let spaces: [Space] = spacesConn.objects(in: 0, with: spacesMappings)

        DispatchQueue.main.async {
            self.store.dispatch(.updateSpaces(spaces))

            if let currentSpace = SelectedSpace.space, spaces.contains(where: { $0.id == currentSpace.id }) {
                if self.store().selectedSpaceId != currentSpace.id {
                    self.store.dispatch(.selectSpace(currentSpace.id))
                }
            } else if let selectedId = self.store().selectedSpaceId, spaces.contains(where: { $0.id == selectedId }) {
                if self.store().selectedSpaceId != selectedId {
                    self.store.dispatch(.selectSpace(selectedId))
                }
            }

            if let space = SelectedSpace.space {
                let currentState = self.store()
                let iconName = space is IaSpace ? "internet_archive" : "private_server"
                if currentState.currentSpaceName != space.prettyName || currentState.currentSpaceIcon != iconName {
                    self.store.dispatch(.updateSpaceHeader(name: space.prettyName, iconName: iconName))
                }
            }
        }
    }

    private func handleProjectsChanges() {
        guard let projectsConn = projectsConn,
              let projectsMappings = projectsMappings else {
            return
        }

        projectsConn.update(mappings: projectsMappings)
        let changes = projectsConn.getChanges(projectsMappings)
        let allProjects: [Project] = projectsConn.objects(in: 0, with: projectsMappings)
        let projects = allProjects.filter(\.active)

        DispatchQueue.main.async {
            self.store.dispatch(.updateProjects(projects))
            self.selectProject(from: projects)
        }
    }

    private func selectProject(from projects: [Project]) {
        let currentId = store().selectedProjectId

        // If there's already a valid selection, keep it - don't auto-change
        if let currentId = currentId, projects.contains(where: { $0.id == currentId }) {
            return
        }

        // Only auto-select if current selection is invalid or missing
        if let currentId = currentId, !projects.contains(where: { $0.id == currentId }) {
            if let next = projects.first {
                store.dispatch(.selectProject(next.id))
                if SelectedProject.project?.id != next.id {
                    SelectedProject.project = next
                    SelectedProject.store()
                }
                coordinator?.selectedProject(next)
            } else {
                store.dispatch(.selectProject(nil))
                if SelectedProject.project != nil {
                    SelectedProject.project = nil
                }
                coordinator?.selectedProject(nil)
            }
        } else if currentId == nil, !projects.isEmpty {
            // No current selection - try to restore previously selected project
            if let selectedProject = SelectedProject.project,
               selectedProject.spaceId == SelectedSpace.id,
               selectedProject.active,
               projects.contains(where: { $0.id == selectedProject.id }) {
                // Restore the previously selected project
                store.dispatch(.selectProject(selectedProject.id))
                coordinator?.selectedProject(selectedProject)
            } else if let first = projects.first {
                // Default to first project if no valid previously selected project
                store.dispatch(.selectProject(first.id))
                if SelectedProject.project?.id != first.id {
                    SelectedProject.project = first
                    SelectedProject.store()
                }
                coordinator?.selectedProject(first)
            }
        }
    }
}

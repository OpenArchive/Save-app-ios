//
//  SideMenuReducer.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

private func areSameSpaces(_ lhs: [Space], _ rhs: [Space]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (index, leftSpace) in lhs.enumerated() {
        let rightSpace = rhs[index]
        // Compare by ID and name to detect changes (not object identity!)
        if leftSpace.id != rightSpace.id || leftSpace.name != rightSpace.name {
            return false
        }
    }
    return true
}

private func areSameProjects(_ lhs: [Project], _ rhs: [Project]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (index, leftProject) in lhs.enumerated() {
        let rightProject = rhs[index]
        // Compare by ID and name to detect changes (not object identity!)
        if leftProject.id != rightProject.id || leftProject.name != rightProject.name {
            return false
        }
    }
    return true
}

let sideMenuReducer: Reducer<SideMenuState, SideMenuAction> = { state, action in
    var newState = state

    switch action {
    case .toggleMenu(let show):
        guard state.isMenuVisible != show else { return nil }
        newState.isMenuVisible = show
        newState.menuWidth = show ? 240 : 0
        if !show { newState.isServersExpanded = false }

    case .setMenuWidth(let width):
        guard state.menuWidth != width else { return nil }
        newState.menuWidth = width

    case .updateSpaces(let spaces):
        // Always update spaces array - don't just check IDs, as space properties might have changed
        guard !areSameSpaces(state.spaces, spaces) else {
            return nil
        }
        newState.spaces = spaces

    case .updateProjects(let projects):
        // Check if projects changed (IDs or names)
        guard !areSameProjects(state.projects, projects) else {
            return nil
        }
        newState.projects = projects

    case .selectSpace(let id):
        guard state.selectedSpaceId != id else {
            return nil
        }
        newState.selectedSpaceId = id
        if !newState.projects.isEmpty && state.selectedProjectId == nil {
            newState.selectedProjectId = newState.projects[0].id
        }

    case .selectProject(let id):
        if state.selectedProjectId == id {
            return nil
        }
        newState.selectedProjectId = id

    case .toggleServersExpanded:
        newState.isServersExpanded.toggle()

    case .updateSpaceHeader(let name, let iconName):
        guard state.currentSpaceName != name || state.currentSpaceIcon != iconName else {
            return nil
        }
        newState.currentSpaceName = name
        newState.currentSpaceIcon = iconName
        newState.showSpaceHeader = true

    case .toggleSpaceHeader(let show):
        guard state.showSpaceHeader != show else { return nil }
        newState.showSpaceHeader = show

    case .setAnimating(let animating):
        guard state.isAnimating != animating else { return nil }
        newState.isAnimating = animating

    case .tapAddServer, .tapAddFolder, .tapServerSettings, .databaseModified:
        return nil
    }

    return newState
}

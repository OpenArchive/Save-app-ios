//
//  SideMenuReducer.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

let sideMenuReducer: Reducer<SideMenuState, SideMenuAction> = { state, action in
    var newState = state
    
    switch action {
    case .toggleMenu(let show):
        if state.isMenuVisible == show {
            return nil
        }
        newState.isMenuVisible = show
        newState.menuWidth = show ? 240 : 0
        if !show { newState.isServersExpanded = false }
        
    case .setMenuWidth(let width):
        if state.menuWidth == width {
            return nil
        }
        newState.menuWidth = width
        
    case .updateSpaces(let spaces):
        newState.spaces = spaces
        
    case .updateProjects(let projects):
        newState.projects = projects
        
    case .selectSpace(let id):
        if state.selectedSpaceId == id {
            return nil
        }
        newState.selectedSpaceId = id
        // Clear selectedProjectId when switching space; observer will select first project
        newState.selectedProjectId = nil
        
    case .selectProject(let id):
        if state.selectedProjectId == id {
            return nil
        }
        newState.selectedProjectId = id
        
    case .toggleServersExpanded:
        newState.isServersExpanded.toggle()
        
    case .updateSpaceHeader(let name, let iconName):
        if state.currentSpaceName == name && state.currentSpaceIcon == iconName {
            return nil
        }
        newState.currentSpaceName = name
        newState.currentSpaceIcon = iconName
        newState.showSpaceHeader = true
        
    case .toggleSpaceHeader(let show):
        if state.showSpaceHeader == show {
            return nil
        }
        newState.showSpaceHeader = show
        
    case .setAnimating(let animating):
        if state.isAnimating == animating {
            return nil
        }
        newState.isAnimating = animating
        
    case .tapAddServer, .tapAddFolder, .tapServerSettings, .databaseModified:
        return nil
    }
    
    return newState
}

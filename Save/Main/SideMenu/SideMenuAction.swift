//
//  SideMenuAction.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

enum SideMenuAction {
    // Menu visibility
    case toggleMenu(show: Bool)
    case setMenuWidth(CGFloat)

    // Data updates
    case updateSpaces([Space])
    case updateProjects([Project])
    case selectSpace(String?)
    case selectProject(String?)

    // UI interactions
    case toggleServersExpanded
    case tapAddServer
    case tapAddFolder
    case tapServerSettings(Space)

    // Space header
    case updateSpaceHeader(name: String, iconName: String)
    case toggleSpaceHeader(show: Bool)

    // Animation state
    case setAnimating(Bool)

    // External updates (from YapDatabase)
    case databaseModified
}

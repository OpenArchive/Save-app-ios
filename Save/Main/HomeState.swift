//
//  HomeState.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import UIKit

struct HomeState: Equatable {
    static let menuWidth: CGFloat = 240

    var isMenuVisible = false
    var spaces: [Space] = []
    var isServersExpanded = false
    var selectedSpaceId: String?
    var projects: [Project] = []
    var selectedProjectId: String?
    var showSpaceHeader = false
    var currentSpaceName = ""
    var currentSpaceIcon = ""
    var isAnimating = false

    static func == (lhs: HomeState, rhs: HomeState) -> Bool {
        lhs.isMenuVisible == rhs.isMenuVisible &&
        lhs.spaces.map(\.id) == rhs.spaces.map(\.id) &&
        lhs.isServersExpanded == rhs.isServersExpanded &&
        lhs.selectedSpaceId == rhs.selectedSpaceId &&
        lhs.projects.map(\.id) == rhs.projects.map(\.id) &&
        lhs.selectedProjectId == rhs.selectedProjectId &&
        lhs.showSpaceHeader == rhs.showSpaceHeader &&
        lhs.currentSpaceName == rhs.currentSpaceName &&
        lhs.currentSpaceIcon == rhs.currentSpaceIcon &&
        lhs.isAnimating == rhs.isAnimating
    }
}

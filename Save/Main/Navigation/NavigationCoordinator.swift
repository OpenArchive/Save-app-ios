//
//  NavigationCoordinator.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation

protocol SideMenuDelegate: AnyObject {
    func hideMenu()
    func selected(project: Project?)
    func addSpace()
    func addFolder()
    func hideSelectMedia()
    func pushPrivateServerSetting(space: Space)
}

class NavigationCoordinator: ObservableObject {
    weak var delegate: SideMenuDelegate?

    init(delegate: SideMenuDelegate? = nil) {
        self.delegate = delegate
    }

    func hideMenu() { delegate?.hideMenu() }
    func selectedProject(_ project: Project?) { delegate?.selected(project: project) }
    func addSpace() { delegate?.addSpace() }
    func addFolder() { delegate?.addFolder() }
    func hideSelectMedia() { delegate?.hideSelectMedia() }
    func pushPrivateServerSetting(space: Space) { delegate?.pushPrivateServerSetting(space: space) }
}

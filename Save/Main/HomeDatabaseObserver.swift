//
//  HomeDatabaseObserver.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

final class HomeDatabaseObserver {
    let spacesConn: YapDatabaseConnection
    let spacesMappings: YapDatabaseViewMappings
    let projectsConn: YapDatabaseConnection?
    let projectsMappings: YapDatabaseViewMappings?
    private let onFetchComplete: ([Space], [Project]) -> Void

    private let fetchQueue = DispatchQueue(label: "HomeDatabaseObserver.fetch", qos: .userInitiated)

    init(
        spacesConn: YapDatabaseConnection,
        spacesMappings: YapDatabaseViewMappings,
        projectsConn: YapDatabaseConnection?,
        projectsMappings: YapDatabaseViewMappings?,
        onFetchComplete: @escaping ([Space], [Project]) -> Void
    ) {
        self.spacesConn = spacesConn
        self.spacesMappings = spacesMappings
        self.projectsConn = projectsConn
        self.projectsMappings = projectsMappings
        self.onFetchComplete = onFetchComplete
        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refresh() {
        fetchQueue.async { [weak self] in
            self?.performFetch()
        }
    }

    @objc func yapDatabaseModified(notification: Notification) {
        fetchQueue.async { [weak self] in
            self?.performFetch()
        }
    }

    private func performFetch() {
        let spaces = fetchSpaces()
        let projects = fetchProjects() ?? []
        print("[HomeDBObserver] performFetch: \(projects.count) projects, ids=\(projects.map(\.id))")

        DispatchQueue.main.async { [weak self] in
            self?.onFetchComplete(spaces, projects)
        }
    }

    private func fetchSpaces() -> [Space] {
        spacesConn.beginLongLivedReadTransaction()
        spacesConn.update(mappings: spacesMappings)
        return spacesConn.objects(in: 0, with: spacesMappings)
    }

    private func fetchProjects() -> [Project]? {
        guard let projectsConn = projectsConn,
              let projectsMappings = projectsMappings else { return nil }
        projectsConn.beginLongLivedReadTransaction()
        projectsConn.update(mappings: projectsMappings)
        let allProjects: [Project] = projectsConn.objects(in: 0, with: projectsMappings)
        return allProjects.filter(\.active)
    }
}

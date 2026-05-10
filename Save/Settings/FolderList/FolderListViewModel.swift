//
//  FolderListViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import Combine
import YapDatabase

final class FolderListViewModel: NSObject, ObservableObject {
    @Published private(set) var projects: [Project] = []
    
    private let archived: Bool
    private var readConn: YapDatabaseConnection?
    private var mappings: YapDatabaseViewMappings?
    
    init(archived: Bool) {
        self.archived = archived
        super.init()
        readConn = Db.newLongLivedReadConn()
        let viewMappings = YapDatabaseViewMappings(groups: ProjectsView.groups, view: ProjectsView.name)
        mappings = viewMappings
        readConn?.update(mappings: viewMappings)
        
        _ = Db.add(observer: self, #selector(yapDatabaseModified))
        reload()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func yapDatabaseModified(_ notification: Notification) {
        guard let mappings = mappings, readConn?.hasChanges(mappings) == true else { return }
        DispatchQueue.main.async { [weak self] in
            self?.reload()
        }
    }
    
    private func reload() {
        guard let readConn = readConn, let mappings = mappings else { return }
        let all: [Project] = readConn.objects(in: 0, with: mappings)
        projects = all.filter { archived != $0.active }
    }
}

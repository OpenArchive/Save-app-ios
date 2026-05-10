//
//  ServerListViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

final class ServerListViewModel: NSObject, ObservableObject {
    @Published private(set) var spaces: [Space] = []
    @Published private(set) var isEmpty: Bool = true
    
    private var spacesConn: YapDatabaseConnection?
    private var spacesMappings: YapDatabaseViewMappings?
    
    override init() {
        super.init()
        spacesConn = Db.newLongLivedReadConn()
        spacesMappings = YapDatabaseViewMappings(groups: SpacesView.groups, view: SpacesView.name)
        
        _ = Db.add(observer: self, #selector(yapDatabaseModified))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func refresh() {
        guard let mappings = spacesMappings else { return }
        spacesConn?.update(mappings: mappings)
        reload()
    }
    
    @objc private func yapDatabaseModified(_ notification: Notification) {
        guard let mappings = spacesMappings, spacesConn?.hasChanges(mappings) == true else { return }
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }
    
    private func reload() {
        guard let conn = spacesConn, let mappings = spacesMappings else { return }
        var result: [Space] = []
        let count = Int(mappings.numberOfItems(inSection: 0))
        for i in 0..<count {
            let indexPath = IndexPath(row: i, section: 0)
            if let space: Space = conn.object(at: indexPath, in: mappings) {
                result.append(space)
            }
        }
        spaces = result
        isEmpty = result.isEmpty
    }
}

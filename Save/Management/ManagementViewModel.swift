//
//  ManagementViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import Combine
@preconcurrency import YapDatabase

@MainActor
class ManagementViewModel: ObservableObject {
    
    @Published var uploads: [Upload] = []
    @Published var titleText: String = NSLocalizedString("Edit Queue", comment: "")
    @Published var subtitleText: String = NSLocalizedString("Uploading is paused", comment: "")
    
    private lazy var readConn = Db.newLongLivedReadConn()
    private lazy var mappings = YapDatabaseViewMappings(groups: UploadsView.groups, view: UploadsView.name)
    private var observer: NSObjectProtocol?
    
    init() {
        setupDatabaseObserver()
        loadUploads()
        removeDone(async: false)
        pauseUploads()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupDatabaseObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .YapDatabaseModified,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDatabaseModified()
            }
        }
    }
    
    private func handleDatabaseModified() {
        guard readConn?.hasChanges(mappings) ?? false else { return }
        loadUploads()
        updateTitle()
    }
    
    func loadUploads() {
        readConn?.update(mappings: mappings)
        
        // Capture mappings on the main actor before entering the Sendable closure
        let mappings = self.mappings
        
        readConn?.read { [weak self] tx in
            guard let self = self else { return }
            var loadedUploads: [Upload] = []
            
            guard let viewTx = tx.forView(mappings.view) else { return }
            
            let count = Int(mappings.numberOfItems(inSection: 0))
            for i in 0..<count {
                if let upload = viewTx.object(at: IndexPath(row: i, section: 0), with: mappings) as? Upload {
                    upload.preheat(tx, deep: false)
                    loadedUploads.append(upload)
                }
            }
            
            DispatchQueue.main.async {
                self.uploads = loadedUploads
            }
        }
    }
    
    func updateTitle() {
        titleText = NSLocalizedString("Edit Queue", comment: "")
        subtitleText = NSLocalizedString("Uploading is paused", comment: "")
    }
    
    func moveUpload(from source: IndexSet, to destination: Int) {
        uploads.move(fromOffsets: source, toOffset: destination)
        
        Db.writeConn?.asyncReadWrite { tx in
            var uploads: [Upload] = tx.findAll(group: UploadsView.groups.first, in: UploadsView.name)
            
            uploads.move(fromOffsets: source, toOffset: destination)
            
            for (index, upload) in uploads.enumerated() {
                if upload.order != index {
                    upload.order = index
                    tx.replace(upload)
                }
            }
        }
    }
    
    func deleteUpload(_ upload: Upload) {
        upload.remove { [weak self] in
            DispatchQueue.main.async {
                self?.loadUploads()
            }
        }
    }
    
    func pauseUploads() {
        NotificationCenter.default.post(name: .uploadManagerPause, object: nil)
    }
    
    func unpauseUploads() {
        NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
    }
    
    func dismiss() {
        unpauseUploads()
        removeDone()
    }
    
    private func removeDone(async: Bool = true) {
        // Capture the collection name to make the closure Sendable-safe
        let collectionName = Upload.collection
        
        let block: @Sendable (YapDatabaseReadWriteTransaction) -> Void = { tx in
            let uploads: [Upload] = tx.findAll { upload in
                upload.preheat(tx, deep: false)
                return upload.state == .uploaded || upload.asset?.isUploaded ?? true
            }
            tx.removeObjects(forKeys: uploads.map({ $0.id }), inCollection: collectionName)
        }
        
        if async {
            Db.writeConn?.asyncReadWrite(block)
        } else {
            Db.writeConn?.readWrite(block)
        }
    }
    
    func canMoveUpload(_ upload: Upload) -> Bool {
        switch upload.state {
        case .pending, .paused, .uploading:
            return true
        default:
            return false
        }
    }
}

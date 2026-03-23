//
//  PreviewViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import Combine
import YapDatabase

@MainActor
class PreviewViewModel: ObservableObject {
    
    @Published var assets: [Asset] = []
    @Published var selectedAssetIds: Set<String> = []
    @Published var isSelectionMode: Bool = false
    @Published var refreshId: UUID = UUID()
    
    private let sc = SelectedCollection()
    private var observer: NSObjectProtocol?
    private var refreshDebounceTask: Task<Void, Never>?
    
    var count: Int {
        assets.count
    }
    
    var selectedCount: Int {
        selectedAssetIds.count
    }
    
    var allSelected: Bool {
        !assets.isEmpty && selectedAssetIds.count == assets.count
    }
    
    var collection: Collection? {
        sc.collection
    }
    
    var projectName: String? {
        sc.collection?.project.name
    }
    
    init() {
        setupDatabaseObserver()
        loadAssets()
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
        let changes = sc.yapDatabaseModified()
        
        if sc.count < 1 {
            assets = []
            return
        }
        
        if changes.forceFull || !changes.rowChanges.isEmpty || !changes.sectionChanges.isEmpty {
            loadAssets()
            scheduleRefresh()
        }
    }
    
    private func scheduleRefresh() {
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            refreshId = UUID()
        }
    }
    
    func loadAssets() {
        var loadedAssets: [Asset] = []
        
        for i in 0..<sc.count {
            if let asset = sc.getAsset(IndexPath(row: i, section: 0)) {
                loadedAssets.append(asset)
            }
        }
        
        assets = loadedAssets
        
        selectedAssetIds = selectedAssetIds.filter { id in
            assets.contains { $0.id == id }
        }
        
        if selectedAssetIds.isEmpty {
            isSelectionMode = false
        }
    }
    
    func toggleSelection(for asset: Asset) {
        if selectedAssetIds.contains(asset.id) {
            selectedAssetIds.remove(asset.id)
            if selectedAssetIds.isEmpty {
                isSelectionMode = false
            }
        } else {
            selectedAssetIds.insert(asset.id)
        }
    }
    
    func selectAsset(_ asset: Asset) {
        selectedAssetIds.insert(asset.id)
        isSelectionMode = true
    }
    
    func deselectAll() {
        selectedAssetIds.removeAll()
        isSelectionMode = false
    }
    
    func selectAll() {
        selectedAssetIds = Set(assets.map { $0.id })
        isSelectionMode = true
    }
    
    func toggleSelectAll() {
        if allSelected {
            deselectAll()
        } else {
            selectAll()
        }
    }
    
    func isSelected(_ asset: Asset) -> Bool {
        selectedAssetIds.contains(asset.id)
    }
    
    func getSelectedAssets() -> [Asset] {
        assets.filter { selectedAssetIds.contains($0.id) }
    }
    
    func removeSelectedAssets() {
        let assetsToRemove = getSelectedAssets()
        guard !assetsToRemove.isEmpty else { return }
        
        deselectAll()
        
        let group = DispatchGroup()
        
        for asset in assetsToRemove {
            group.enter()
            asset.remove {
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.loadAssets()
        }
    }
    
    func upload(completion: @escaping () -> Void) {
        // Capture main actor-isolated values before entering the Sendable closure
        let group = sc.group
        let collectionId = sc.id
        
        Db.writeConn?.asyncReadWrite { tx in
            guard let group else {
                DispatchQueue.main.async { completion() }
                return
            }
            
            var order = 0
            
            tx.iterate { (key, upload: Upload, stop) in
                if upload.order >= order {
                    order = upload.order + 1
                }
            }
            
            if let collectionId,
               let collection: Collection = tx.object(for: collectionId) {
                collection.close()
                tx.setObject(collection)
            }
            
            tx.iterate(group: group, in: AbcFilteredByCollectionView.name) { (collection, key, asset: Asset, index, stop) in
                let upload = Upload(order: order, asset: asset)
                tx.setObject(upload)
                order += 1
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

//
//  MediaGridSection.swift
//  Save
//
//  Created by navoda on 2026-03-23.
//  Copyright © 2026 Open Archive. All rights reserved.
//


import Foundation
import SwiftUI
import YapDatabase

/// Section data for the media grid: a collection with its assets.
struct MediaGridSection: Identifiable {
    let id: String
    let collection: Collection?
    let assets: [Asset]
    let group: String
}

@MainActor
final class MediaGridViewModel: NSObject, ObservableObject {

    @Published private(set) var sections: [MediaGridSection] = []
    @Published private(set) var totalItemCount: Int = 0
    @Published private(set) var isRefreshing = false
    @Published var isInEditMode = false
    @Published private(set) var selectedAssetIds: Set<String> = []

    var hasSelection: Bool { !selectedAssetIds.isEmpty }

    private let assetsReadConn: YapDatabaseConnection?
    private let collectionsReadConn: YapDatabaseConnection?
    private let uploadsReadConn: YapDatabaseConnection?
    private let assetsMappings: YapDatabaseViewMappings
    private let collectionsMappings: YapDatabaseViewMappings
    private let uploadsMappings: YapDatabaseViewMappings

    private var selectedProjectId: String?

    init(
        assetsReadConn: YapDatabaseConnection?,
        collectionsReadConn: YapDatabaseConnection?,
        uploadsReadConn: YapDatabaseConnection?,
        assetsMappings: YapDatabaseViewMappings,
        collectionsMappings: YapDatabaseViewMappings,
        uploadsMappings: YapDatabaseViewMappings
    ) {
        self.assetsReadConn = assetsReadConn
        self.collectionsReadConn = collectionsReadConn
        self.uploadsReadConn = uploadsReadConn
        self.assetsMappings = assetsMappings
        self.collectionsMappings = collectionsMappings
        self.uploadsMappings = uploadsMappings

        super.init()

        debugLogMissingConnections(context: "init")
        updateAllMappings()
        rebuildSections()
    }

    /// Call when the selected project changes. Updates the filter and rebuilds sections.
    func setSelectedProject(_ projectId: String?) {
        selectedProjectId = projectId
        isRefreshing = true
        debugLogMissingConnections(context: "setSelectedProject")
        // Advance long-lived read transactions so mapping reads see the latest committed snapshot.
        _ = assetsReadConn?.beginLongLivedReadTransaction()
        _ = collectionsReadConn?.beginLongLivedReadTransaction()
        _ = uploadsReadConn?.beginLongLivedReadTransaction()
        updateAllMappings()
        rebuildSections()
        isRefreshing = false
    }

    /// Returns the upload for the given asset if it exists and is not yet uploaded.
    func upload(for assetId: String) -> Upload? {
        var result: Upload?
        uploadsReadConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, stop: inout Bool) in
                guard upload.state != .uploaded, upload.assetId == assetId else { return }
                result = upload
                stop = true
            }
        }
        return result
    }

    func selectAsset(_ assetId: String) {
        selectedAssetIds.insert(assetId)
    }

    func deselectAsset(_ assetId: String) {
        selectedAssetIds.remove(assetId)
    }

    func toggleSelection(_ assetId: String) {
        if selectedAssetIds.contains(assetId) {
            selectedAssetIds.remove(assetId)
        } else {
            selectedAssetIds.insert(assetId)
        }
    }

    func toggleEditMode() {
        isInEditMode.toggle()
        if !isInEditMode {
            selectedAssetIds.removeAll()
        }
    }

    func enterEditMode(selecting assetId: String? = nil) {
        isInEditMode = true
        if let assetId = assetId {
            selectedAssetIds.insert(assetId)
        }
    }

    func clearSelection() {
        selectedAssetIds.removeAll()
    }

    /// Exits edit mode and clears selection. Call when closing the select-media bar.
    func exitEditMode() {
        isInEditMode = false
        selectedAssetIds.removeAll()
    }

    func selectedAssets() -> [Asset] {
        assetsReadConn?.objects(at: indexPathsForSelectedAssets(), in: assetsMappings) ?? []
    }

    func rebuildSections() {
        guard let selectedProjectId else {
            sections = []
            totalItemCount = 0
            return
        }

        let sectionCount = Int(assetsMappings.numberOfSections())
        var newSections: [MediaGridSection] = []
        var total = 0

        for sectionIndex in 0..<sectionCount {
            guard let group = assetsMappings.group(forSection: UInt(sectionIndex)) else {
                continue
            }

            // Keep parsing centralized in AssetsByCollectionView to avoid duplicating group format assumptions.
            guard AssetsByCollectionView.projectId(from: group) == selectedProjectId else {
                continue
            }

            let collectionId = AssetsByCollectionView.collectionId(from: group)
            let collection: Collection? = collectionsReadConn?.object(for: collectionId, in: Collection.collection)
            let assets: [Asset] = assetsReadConn?.objects(in: sectionIndex, with: assetsMappings) ?? []
            if assets.isEmpty {
                continue
            }

            if let col = collection {
                col.assets.removeAll()
                col.assets.append(contentsOf: assets)
            }

            let sectionId = group
            newSections.append(MediaGridSection(
                id: sectionId,
                collection: collection,
                assets: assets,
                group: group
            ))
            total += assets.count
        }

        sections = newSections
        totalItemCount = total
    }

    private func updateAllMappings() {
        assetsReadConn?.update(mappings: assetsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        uploadsReadConn?.update(mappings: uploadsMappings)
    }

    private func debugLogMissingConnections(context: String) {
#if DEBUG
        if assetsReadConn == nil || collectionsReadConn == nil || uploadsReadConn == nil {
            assertionFailure("[MediaGridViewModel] Missing YapDatabase connection(s) in \(context)")
        }
#endif
    }

    private func indexPathsForSelectedAssets() -> [IndexPath] {
        var result: [IndexPath] = []
        for (sectionIndex, section) in sections.enumerated() {
            for (itemIndex, asset) in section.assets.enumerated() {
                if selectedAssetIds.contains(asset.id) {
                    result.append(IndexPath(item: itemIndex, section: sectionIndex))
                }
            }
        }
        return result
    }
}

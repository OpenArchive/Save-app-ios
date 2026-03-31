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
    @Published private(set) var uploadsByAssetId: [String: Upload] = [:]
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

        assetsReadConn?.update(mappings: assetsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        uploadsReadConn?.update(mappings: uploadsMappings)
        rebuildSections()
    }

    /// Call when the selected project changes. Updates the filter and rebuilds sections.
    func setSelectedProject(_ projectId: String?) {
        selectedProjectId = projectId
        isRefreshing = true
        _ = assetsReadConn?.beginLongLivedReadTransaction()
        _ = collectionsReadConn?.beginLongLivedReadTransaction()
        _ = uploadsReadConn?.beginLongLivedReadTransaction()
        assetsReadConn?.update(mappings: assetsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        uploadsReadConn?.update(mappings: uploadsMappings)
        rebuildUploadIndex()
        rebuildSections()
        isRefreshing = false
    }

    /// Returns the upload for the given asset if it exists and is not yet uploaded.
    func upload(for assetId: String) -> Upload? {
        uploadsByAssetId[assetId]
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

    private func rebuildUploadIndex() {
        var next: [String: Upload] = [:]
        uploadsReadConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_, upload: Upload, _) in
                guard upload.state != .uploaded, let assetId = upload.assetId else { return }
                next[assetId] = upload
            }
        }
        uploadsByAssetId = next
    }

    func rebuildSections() {
        let sectionCount = Int(assetsMappings.numberOfSections())
        var newSections: [MediaGridSection] = []
        var total = 0

        for sectionIndex in 0..<sectionCount {
            guard let group = assetsMappings.group(forSection: UInt(sectionIndex)) else {
                continue
            }

            guard let selectedProjectId,
                  AssetsByCollectionView.projectId(from: group) == selectedProjectId else {
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

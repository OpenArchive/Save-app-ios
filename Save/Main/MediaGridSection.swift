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
    /// Populated in `rebuildSections()` so `upload(for:)` is O(1) instead of scanning Yap per call.
    @Published private(set) var uploadsByAssetId: [String: Upload] = [:]
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
        _ = assetsReadConn?.beginLongLivedReadTransaction()
        _ = collectionsReadConn?.beginLongLivedReadTransaction()
        _ = uploadsReadConn?.beginLongLivedReadTransaction()
        updateAllMappings()
        rebuildSections()
        isRefreshing = false
    }

    /// Refresh only when Yap mappings report changes — avoids rebuilding the full asset grid on upload progress ticks.
    func applyDatabaseChangesIfNeeded() {
        guard selectedProjectId != nil else { return }

        _ = assetsReadConn?.beginLongLivedReadTransaction()
        _ = collectionsReadConn?.beginLongLivedReadTransaction()
        _ = uploadsReadConn?.beginLongLivedReadTransaction()

        let assetsChanged = assetsReadConn?.hasChanges(assetsMappings) ?? false
        let collectionsChanged = collectionsReadConn?.hasChanges(collectionsMappings) ?? false

        // Always diff the upload map — progress/error changes do not always flip view mappings.
        uploadsReadConn?.update(mappings: uploadsMappings)
        let uploadsMapChanged = rebuildUploadsByAssetIdIfChanged()

        if assetsChanged || collectionsChanged {
            updateAllMappings()
            rebuildSections()
        } else if uploadsMapChanged {
            objectWillChange.send()
        }
    }

    /// Force-refresh upload state from the database (e.g. after upload start/progress).
    func refreshUploadsFromDatabase() {
        guard selectedProjectId != nil else { return }
        _ = uploadsReadConn?.beginLongLivedReadTransaction()
        uploadsReadConn?.update(mappings: uploadsMappings)
        if rebuildUploadsByAssetIdIfChanged() {
            objectWillChange.send()
        }
    }

    /// Lookup from `uploadsByAssetId` (refreshed on each `rebuildSections()`).
    func upload(for assetId: String) -> Upload? {
        uploadsByAssetId[assetId]
    }

    private func rebuildUploadsByAssetIdIfChanged() -> Bool {
        var map: [String: Upload] = [:]
        uploadsReadConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, _: inout Bool) in
                guard upload.state != .uploaded, let aid = upload.assetId else { return }
                if let live = UploadManager.shared.displayProgress(for: upload.id) {
                    upload.progress = live
                }
                if map[aid] == nil {
                    map[aid] = upload
                }
            }
        }
        guard !uploadMapsEquivalent(uploadsByAssetId, map) else { return false }
        uploadsByAssetId = map
        return true
    }

    private func uploadMapsEquivalent(_ lhs: [String: Upload], _ rhs: [String: Upload]) -> Bool {
        if lhs.count != rhs.count { return false }
        for (id, oldUpload) in lhs {
            guard let newUpload = rhs[id] else { return false }
            if oldUpload.state != newUpload.state { return false }
            if oldUpload.paused != newUpload.paused { return false }
            if oldUpload.error != newUpload.error { return false }
            if abs(oldUpload.progress - newUpload.progress) > 0.001 { return false }
        }
        return true
    }

    private func rebuildUploadsByAssetId() {
        _ = rebuildUploadsByAssetIdIfChanged()
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
        sections.flatMap(\.assets).filter { selectedAssetIds.contains($0.id) }
    }

    func rebuildSections() {
        guard let selectedProjectId else {
            sections = []
            totalItemCount = 0
            uploadsByAssetId = [:]
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
        rebuildUploadsByAssetId()
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
}

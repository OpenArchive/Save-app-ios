//
//  DarkroomViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import Combine
import YapDatabase

@MainActor
class DarkroomViewModel: ObservableObject {
    
    @Published var assets: [Asset] = []
    @Published var selectedIndex: Int = 0
    @Published var location: String = ""
    @Published var notes: String = ""
    @Published var isFlagged: Bool = false
    
    private let sc = SelectedCollection()
    private var observer: NSObjectProtocol?
    
    var count: Int {
        assets.count
    }
    
    var currentAsset: Asset? {
        guard selectedIndex >= 0 && selectedIndex < assets.count else { return nil }
        return assets[selectedIndex]
    }
    
    var counterText: String {
        String(format: NSLocalizedString("%1$@/%2$@", comment: "both are integer numbers meaning 'x of n'"),
               Formatters.format(selectedIndex + 1), Formatters.format(count))
    }
    
    var canGoBackward: Bool {
        selectedIndex > 0
    }
    
    var canGoForward: Bool {
        selectedIndex < count - 1
    }
    
    init(initialIndex: Int = 0) {
        self.selectedIndex = initialIndex
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
        let (forceFull, sectionChanges, rowChanges) = sc.yapDatabaseModified()
        
        if forceFull {
            loadAssets()
            return
        }
        
        if sectionChanges.isEmpty && rowChanges.isEmpty {
            return
        }
        
        for change in sectionChanges {
            if change.type == .delete {
                assets = []
                return
            }
        }
        
        for change in rowChanges {
            if change.type == .delete && change.indexPath?.row == selectedIndex {
                if selectedIndex >= sc.count {
                    selectedIndex = max(0, sc.count - 1)
                }
                loadAssets()
                return
            }
        }
        
        loadAssets()
    }
    
    func loadAssets() {
        var loadedAssets: [Asset] = []
        
        for i in 0..<sc.count {
            if let asset = sc.getAsset(IndexPath(row: i, section: 0)) {
                loadedAssets.append(asset)
            }
        }
        
        assets = loadedAssets
        
        if selectedIndex >= assets.count {
            selectedIndex = max(0, assets.count - 1)
        }
        
        updateInfoFields()
    }
    
    func updateInfoFields() {
        guard let asset = currentAsset else {
            location = ""
            notes = ""
            isFlagged = false
            return
        }
        
        location = asset.location ?? ""
        notes = asset.notes ?? ""
        isFlagged = asset.flagged
    }
    
    func saveCurrentAssetInfo() {
        guard let asset = currentAsset else { return }
        
        asset.update { proxy in
            proxy.location = self.location.isEmpty ? nil : self.location
            proxy.notes = self.notes.isEmpty ? nil : self.notes
            proxy.flagged = self.isFlagged
        }
    }
    
    func goBackward() {
        guard canGoBackward else { return }
        saveCurrentAssetInfo()
        selectedIndex -= 1
        updateInfoFields()
    }
    
    func goForward() {
        guard canGoForward else { return }
        saveCurrentAssetInfo()
        selectedIndex += 1
        updateInfoFields()
    }
    
    func onPageChange(to newIndex: Int) {
        guard newIndex != selectedIndex else { return }
        saveCurrentAssetInfo()
        selectedIndex = newIndex
        updateInfoFields()
    }
    
    func toggleFlagged() {
        isFlagged.toggle()
        saveCurrentAssetInfo()
        FlagInfoAlert.presentIfNeeded()
    }
    
    func removeCurrentAsset(completion: @escaping (Bool) -> Void) {
        guard let asset = currentAsset else {
            completion(false)
            return
        }
        
        asset.remove { [weak self] in
            DispatchQueue.main.async {
                self?.loadAssets()
                completion(self?.assets.isEmpty ?? true)
            }
        }
    }
    
    func updateLocation(_ newLocation: String) {
        location = newLocation
    }
    
    func updateNotes(_ newNotes: String) {
        notes = newNotes
    }
}

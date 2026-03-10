//
//  BrowseViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import SwiftUI

struct BrowseFolder: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let modifiedDate: Date?
    let original: Any?
    
    init(_ name: String, _ modifiedDate: Date?, _ original: Any?) {
        self.name = name
        self.modifiedDate = modifiedDate
        self.original = original
    }
    
    init(_ original: FileInfo) {
        self.init(original.name, original.modifiedDate ?? original.creationDate, original)
    }
    
    static func == (lhs: BrowseFolder, rhs: BrowseFolder) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class BrowseViewModel: ObservableObject {
    @Published private(set) var sections: [BrowseSection] = []
    @Published private(set) var isLoading = false
    @Published var selectedFolder: BrowseFolder?

    private let useTorSession: Bool

    /// - Parameter useTorSession: When true, uses `UploadManager.improvedSessionConf()` so that
    ///   WebDAV browse requests can route through Tor when Onion Routing is enabled (see Settings).
    ///   Used when coming from main app's Add Folder → Browse (WebDavSpace). When Tor is re-enabled,
    ///   uncomment the Tor proxy block in `UploadManager.improvedSessionConf()`.
    init(useTorSession: Bool = false) {
        self.useTorSession = useTorSession
    }

    func loadFolders() {
        isLoading = true
        sections = []

        guard let space = SelectedSpace.space as? WebDavSpace, let url = space.url else {
            isLoading = false
            return
        }

        // Use UploadManager session when useTorSession so browse respects Tor (when re-enabled).
        // See UploadManager.improvedSessionConf() for Tor proxy setup.
        let config = useTorSession
            ? UploadManager.improvedSessionConf()
            : URLSessionConfiguration.improved()
        let session = URLSession(configuration: config)
        
        session.info(url, credential: space.credential) { [weak self] info, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.sections = [BrowseSection(header: "", items: [.error(error)])]
                    return
                }
                
                var folders: [BrowseFolder] = []
                let files = info.dropFirst().sorted { f1, f2 in
                    let d1 = f1.modifiedDate ?? f1.creationDate ?? Date(timeIntervalSince1970: 0)
                    let d2 = f2.modifiedDate ?? f2.creationDate ?? Date(timeIntervalSince1970: 0)
                    return d1 > d2
                }
                for file in files {
                    if file.type == .directory && !file.isHidden {
                        folders.append(BrowseFolder(file))
                    }
                }
                self.sections = [BrowseSection(header: "", items: folders.map { .folder($0) })]
            }
        }
    }

    var emptyMessage: String {
        NSLocalizedString("No folders available to add.", comment: "No folders available to add.")
    }
}

struct BrowseSection: Identifiable {
    let id = UUID()
    let header: String
    let items: [BrowseItem]
}

enum BrowseItem: Identifiable {
    case folder(BrowseFolder)
    case error(Error)
    
    var id: String {
        switch self {
        case .folder(let f): return f.id.uuidString
        case .error(let e): return (e as NSError).description
        }
    }
}

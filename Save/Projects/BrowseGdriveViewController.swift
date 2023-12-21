//
//  BrowseGdriveViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST

extension BrowseViewController.Folder {

    convenience init?(_ original: GTLRDrive_File) {
        guard let name = original.name ?? original.identifier else {
            return nil
        }

        self.init(name, original.modifiedTime?.date ?? original.createdTime?.date, original)
    }
}

class BrowseGdriveViewController: BrowseViewController {


    override func loadFolders() {
        beginWork {
            folders.removeAll()

            GdriveConduit.list(type: GdriveConduit.folderMimeType) { files, error in
                if let error = error {
                    debugPrint("[\(String(describing: type(of: self)))] error=\(error)")

                    return self.endWork(error)
                }

                for file in files {
                    if file.trashed == nil || file.trashed! == 0, let folder = Folder(file) {
                        self.folders.append(folder)
                    }
                }

                self.endWork(nil)
            }
        }
    }
}

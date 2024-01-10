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
            data.removeAll()
            headers.removeAll()

            GdriveConduit.list(type: GdriveConduit.folderMimeType) { files, error in
                if let error = error {
                    debugPrint("[\(String(describing: type(of: self)))] error=\(error)")

                    self.data.append([error])

                    return self.endWork()
                }

                var myDrive = [Folder]()
                var sharedWithMe = [Folder]()

                for file in files {
                    if file.trashed == nil || file.trashed! == 0, let folder = Folder(file) {
                        if file.parents?.isEmpty ?? true {
                            sharedWithMe.append(folder)
                        }
                        else {
                            // If the parent is also in our list, ignore that folder
                            // since it's not a root folder.
                            if files.contains(where: { f in file.parents?.contains(where: { $0 == f.identifier }) ?? false }) {
                                continue
                            }

                            myDrive.append(folder)
                        }
                    }
                }

                if !myDrive.isEmpty {
                    self.headers.append(NSLocalizedString(
                        "My Drive",
                        comment: "Google Drive! Please provide same translation as Google uses!"))

                    self.data.append(myDrive)
                }

                if !sharedWithMe.isEmpty {
                    self.headers.append(NSLocalizedString(
                        "Files Shared With Me",
                        comment: "Google Drive! Please provide same translation as Google uses!"))

                    self.data.append(sharedWithMe)
                }

                self.endWork()
            }
        }
    }
}

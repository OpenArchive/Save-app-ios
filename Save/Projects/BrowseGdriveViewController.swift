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

            let query = GTLRDriveQuery_FilesList.query()
            query.spaces = "drive"
            query.corpora = "user,allTeamDrives"
            query.q = "mimeType='application/vnd.google-apps.folder' and trashed=false"
            query.includeItemsFromAllDrives = true
            query.supportsAllDrives = true
            query.orderBy = "name_natural"
            query.pageSize = 999
            query.fields = "files(id,name,modifiedTime,createdTime)"

            GdriveConduit.service.executeQuery(query) { a, result, error in
                if let error = error {
                    debugPrint("[\(String(describing: type(of: self)))] error=\(error)")

                    return self.endWork(error)
                }

                guard let folders = result as? GTLRDrive_FileList else {
                    return self.endWork(nil)
                }

                for file in folders.files ?? [] {
                    if file.trashed == nil || file.trashed! == 0, let folder = Folder(file) {
                        self.folders.append(folder)
                    }
                }

                self.endWork(nil)
            }
        }
    }
}

//
//  BrowseDropboxViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import SwiftyDropbox

extension BrowseViewController.Folder {

    convenience init(_ original: Files.FolderMetadata) {
        self.init(original.name, nil, original)
    }
}

class BrowseDropboxViewController: BrowseViewController {

    override func loadFolders() {
        beginWork {
            data.removeAll()

            if let client = DropboxConduit.client {
                client.files.listFolder(path: "", includeNonDownloadableFiles: false)
                    .response(completionHandler: dropboxCompletionHandler)
            }
            else {
                self.endWork()
            }
        }
    }

    private func dropboxCompletionHandler<T: CustomStringConvertible>(_ result: Files.ListFolderResult?, _ error: CallError<T>?) {
        if let error = error {
            debugPrint("[\(String(describing: type(of: self)))] error=\(error)")

            if let error = NSError.from(error) {
                data.insert([error], at: 0)
            }

            return self.endWork()
        }

        for entry in result?.entries ?? [] {
            if let entry = entry as? Files.FolderMetadata {
                if var folders = self.data.last as? [Folder] {
                    folders.append(Folder(entry))

                    self.data[self.data.count - 1] = folders
                }
                else {
                    self.data.append([Folder(entry)])
                }
            }
        }

        if result?.hasMore ?? false {
            DropboxConduit.client?.files.listFolderContinue(cursor: result!.cursor)
                .response(completionHandler: dropboxCompletionHandler)
        }
        else {
            self.endWork()
        }
    }
}

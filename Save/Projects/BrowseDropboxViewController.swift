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
            folders.removeAll()

            if let client = DropboxConduit.client {
                client.files.listFolder(path: "", includeNonDownloadableFiles: false)
                    .response(completionHandler: dropboxCompletionHandler)
            }
            else {
                self.endWork(nil)
            }
        }
    }

    private func dropboxCompletionHandler<T: CustomStringConvertible>(_ result: Files.ListFolderResult?, _ error: CallError<T>?) {
        if let error = error {
            debugPrint("[\(String(describing: type(of: self)))] error=\(error)")

            return self.endWork(NSError.from(error))
        }

        for entry in result?.entries ?? [] {
            if let entry = entry as? Files.FolderMetadata {
                self.folders.append(Folder(entry))
            }
        }

        if result?.hasMore ?? false {
            DropboxConduit.client?.files.listFolderContinue(cursor: result!.cursor)
                .response(completionHandler: dropboxCompletionHandler)
        }
        else {
            self.endWork(nil)
        }
    }
}

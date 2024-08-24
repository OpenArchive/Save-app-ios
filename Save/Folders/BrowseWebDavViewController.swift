//
//  BrowseWebDavViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 15.03.24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class BrowseWebDavViewController: BrowseViewController {

    /**
     The only difference to `BrowseViewController` is the fact, that it uses
     a session configuration from `UploadManager` which will make sure to
     add Tor as the SOCKS5 proxy, if the user said we should use Tor.
     */
    override func loadFolders() {
        beginWork {
            data.removeAll()

            guard let space = SelectedSpace.space as? WebDavSpace, let url = space.url else {
                return self.endWork()
            }

            URLSession(configuration: UploadManager.improvedSessionConf()).info(url, credential: space.credential) { info, error in
                if let error = error {
                    self.data.append([error])

                    return
                }

                var folders = [Folder]()

                let files = info.dropFirst().sorted(by: {
                    $0.modifiedDate ?? $0.creationDate ?? Date(timeIntervalSince1970: 0)
                    > $1.modifiedDate ?? $1.creationDate ?? Date(timeIntervalSince1970: 0)
                })

                for file in files {
                    if file.type == .directory && !file.isHidden {
                        folders.append(Folder(file))
                    }
                }

                self.data.append(folders)

                self.endWork()
            }
        }
    }
}

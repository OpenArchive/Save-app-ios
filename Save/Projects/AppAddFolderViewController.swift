//
//  AppAddFolderViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class AppAddFolderViewController: AddFolderViewController {

    override var noBrowse: Bool {
        SelectedSpace.space is IaSpace
    }


    override func browse() {
        switch SelectedSpace.space {
        case is WebDavSpace:
            navigationController?.pushViewController(BrowseWebDavViewController(), animated: true)

        case is DropboxSpace:
            navigationController?.pushViewController(BrowseDropboxViewController(), animated: true)

        case is GdriveSpace:
            navigationController?.pushViewController(BrowseGdriveViewController(), animated: true)

        default:
            super.browse()
        }
    }
}

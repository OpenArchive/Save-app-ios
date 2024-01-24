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
        SelectedSpace.space is IaSpace || (SelectedSpace.space is GdriveSpace && !GdriveConduit.canReadFolders)
    }


    override func browse() {
        switch SelectedSpace.space {
        case is DropboxSpace:
            navigationController?.pushViewController(BrowseDropboxViewController(), animated: true)

        case is GdriveSpace:
            navigationController?.pushViewController(BrowseGdriveViewController(), animated: true)

        default:
            super.browse()
        }
    }
}

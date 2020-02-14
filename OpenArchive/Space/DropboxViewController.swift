//
//  DropboxViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.02.20.
//  Copyright © 2020 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import SwiftyDropbox

class DropboxViewController: BaseServerViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Dropbox".localize()

        favIconRow.value = DropboxSpace.favIcon

        let actionSection = Section()

        form
            +++ favIconRow

            +++ actionSection

        if space != nil {
            actionSection
                <<< removeRow
        }
        else {
            actionSection
                <<< ButtonRow() {
                    $0.title = "Authenticate".localize()
                }
                .cellUpdate({ cell, _ in
                    cell.textLabel?.textColor = .accent
                })
                .onCellSelection({ cell, row in
                    DropboxClientsManager.authorizeFromController(
                    UIApplication.shared, controller: self) { url in
                        UIApplication.shared.open(url, options: [:])
                    }
                })
        }
    }
}

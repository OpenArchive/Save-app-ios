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

/**
 https://github.com/dropbox/SwiftyDropbox
 */
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
                .onCellSelection({ _, _ in
                    DropboxClientsManager.authorizeFromControllerV2(
                        UIApplication.shared,
                        controller: self,
                        loadingStatusDelegate: nil,
                        openURL: { UIApplication.shared.open($0, options: [:]) },
                        scopeRequest: ScopeRequest(scopeType: .user, scopes: [], includeGrantedScopes: false))

                    // Will continue in AppDelegateBase, where we receive a callback.
                })
        }
    }
}

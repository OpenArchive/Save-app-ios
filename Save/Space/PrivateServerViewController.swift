//
//  PrivateServerViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import FavIcon
import YapDatabase

class PrivateServerViewController: BaseServerViewController {

    private let nameRow = TextRow() {
        $0.title = NSLocalizedString("Server Name", comment: "")
        $0.placeholder = NSLocalizedString("Optional", comment: "")
    }

    private let urlRow = URLRow() {
        $0.title = NSLocalizedString("Server URL", comment: "")
        $0.placeholder = NSLocalizedString("Required", comment: "")
        $0.add(rule: RuleRequired())
        $0.formatter = Formatters.URLFormatter()
    }

    private let passwordRow = PasswordRow() {
        $0.title = NSLocalizedString("Password", comment: "")
        $0.placeholder = NSLocalizedString("Required", comment: "")
        $0.add(rule: RuleRequired())
    }

    private let nextcloudRow = SwitchRow() {
        $0.title = NSLocalizedString("Use Upload Chunking (Nextcloud only)", comment: "")
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Private (WebDAV) Server", comment: "")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: space != nil ? NSLocalizedString("Done", comment: "") : NSLocalizedString("Connect", comment: ""),
            style: .done, target: self,
            action: #selector(connect))

        favIconRow.value = space?.favIcon
        nameRow.value = space?.name
        urlRow.value = space?.url
        userNameRow.value = space?.username
        passwordRow.value = space?.password
        nextcloudRow.value = space?.isNextcloud

        form
            +++ Section()

            <<< favIconRow

            <<< nameRow

            <<< urlRow.cellUpdate() { _, row in
                self.acquireFavIcon()
                self.enableConnect()
            }

            <<< userNameRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            <<< passwordRow.cellUpdate() { _, _ in
                self.enableConnect()
            }

            <<< LabelRow() {
                $0.title = String(format: NSLocalizedString("__webdav_description__", comment: ""), Bundle.main.displayName)
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
                $0.cell.textLabel?.adjustsFontForContentSizeCategory = true
            }

            +++ nextcloudRow

            <<< LabelRow() {
                $0.title = NSLocalizedString("__upload_chunking_description__", comment: "")
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
                $0.cell.textLabel?.adjustsFontForContentSizeCategory = true
            }

        if space != nil {
            form
                +++ removeRow
        }

        form.validate()
        enableConnect()
    }


    // MARK: Actions

    @objc override func connect() {
        workingOverlay.isHidden = false

        if space == nil {
            space = WebDavSpace()
            isEdit = false
        }
        else if isEdit == nil {
            isEdit = true
        }

        space?.name = nameRow.value
        space?.url = Formatters.URLFormatter.fix(url: urlRow.value)
        space?.favIcon = favIconRow.value
        space?.username = userNameRow.value
        space?.password = passwordRow.value
        space?.isNextcloud = nextcloudRow.value ?? false

        // Do a test request to check validity of space configuration.
        if let space = space as? WebDavSpace, let url = space.url {
            space.session.info(url) { info, error in
                DispatchQueue.main.async {
                    self.workingOverlay.isHidden = true

                    if let error = error {
                        AlertHelper.present(self, message: error.friendlyMessage)
                    }
                    else {
                        super.connect()
                    }
                }
            }
        }
        else {
            workingOverlay.isHidden = true

            AlertHelper.present(self, message: NSLocalizedString("Unknown error.", comment: ""))
        }
    }


    // MARK: Private Methods

    private func acquireFavIcon() {
        if let baseUrl = Formatters.URLFormatter.fix(url: urlRow.value, baseOnly: true) {
            FavIcon.downloadSession = URLSession.withImprovedConf()

            try! FavIcon.downloadPreferred(baseUrl) { result in
                if case let .success(image) = result {
                    self.favIconRow.value = image
                    self.favIconRow.reload()
                }
            }
        }
    }

    private func enableConnect() {
        navigationItem.rightBarButtonItem?.isEnabled = urlRow.isValid
            && userNameRow.isValid && passwordRow.isValid
    }
}

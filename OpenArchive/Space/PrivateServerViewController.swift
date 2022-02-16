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
        $0.title = "Server Name".localize()
        $0.placeholder = "Optional".localize()
    }

    private let urlRow = URLRow() {
        $0.title = "Server URL".localize()
        $0.placeholder = "Required".localize()
        $0.add(rule: RuleRequired())
        $0.formatter = Formatters.URLFormatter()
    }

    private let passwordRow = PasswordRow() {
        $0.title = "Password".localize()
        $0.placeholder = "Required".localize()
        $0.add(rule: RuleRequired())
    }

    private let nextcloudRow = SwitchRow() {
        $0.title = "Use Upload Chunking (Nextcloud only)".localize()
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.cell.switchControl.onTintColor = .accent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Private (WebDAV) Server".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: space != nil ? "Done".localize() : "Connect".localize(),
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
                $0.title = "__webdav_description__".localize(value: Bundle.main.displayName)
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .systemFont(ofSize: 12)
            }

            +++ nextcloudRow

            <<< LabelRow() {
                $0.title = "__upload_chunking_description__".localize()
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .systemFont(ofSize: 12)
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
        (space as? WebDavSpace)?.provider?.attributesOfItem(path: "") { file, error in
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


    // MARK: Private Methods

    private func acquireFavIcon() {
        if let baseUrl = Formatters.URLFormatter.fix(url: urlRow.value, baseOnly: true) {

            let conf = TorManager.shared.sessionConf()
            FavIcon.downloadSession = URLSession(configuration: conf)

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

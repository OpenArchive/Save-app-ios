//
//  InternetArchiveViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class InternetArchiveViewController: BaseServerViewController, ScrapeDelegate {

    static let keysUrl = URL(string: "https://archive.org/account/s3.php")!

    private let secretKeyRow = AccountRow() {
        $0.title = "Secret Key".localize()
        $0.placeholder = "Required".localize()
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Internet Archive".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: space != nil ? "Done".localize() : "Connect".localize(),
            style: .done, target: self,
            action: #selector(connect))

        favIconRow.value = IaSpace.favIcon
        userNameRow.title = "Access Key".localize()
        userNameRow.value = space?.username
        secretKeyRow.value = space?.password

        let actionSection = Section()

        form
            +++ favIconRow

            <<< userNameRow.cellUpdate(enableConnect(_:_:))

            <<< secretKeyRow.cellUpdate(enableConnect(_:_:))

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .systemFont(ofSize: 11)

                let appName = Bundle.main.displayName

                $0.title = "% needs your Internet Archive account's API keys to be able to upload to it."
                    .localize(value: appName)
                    + "\n\n"
                    + "You can let % try to acquire these keys automatically, or you can tap this row which will send you to % in Safari from where you can copy-and-paste these keys manually."
                        .localize(values: appName, InternetArchiveViewController.keysUrl.absoluteString)
                    + "\n\n"
                    + "When using the \"%\" feature, make sure to log in and then touch the \"Refresh\" button in the top right to let % have another try at automatically scraping the keys."
                        .localize(values: "Acquire Keys".localize(), appName)
                }
                .onCellSelection() { _, _ in
                    UIApplication.shared.open(InternetArchiveViewController.keysUrl, options: [:])
            }

            +++ actionSection

            <<< ButtonRow() {
                $0.title = "Acquire Keys".localize()
            }
            .cellUpdate({ cell, _ in
                cell.textLabel?.textColor = .accent
            })
            .onCellSelection({ cell, row in
                let vc = IaScrapeViewController()
                vc.delegate = self

                self.navigationController?.pushViewController(vc, animated: true)
            })

        if space != nil {
            actionSection
                <<< removeRow
        }

        form.validate()
        enableConnect()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        IaInfoAlert.presentIfNeeded(self)
    }


    // MARK: Actions

    @objc override func connect() {
        if space == nil {
            space = IaSpace()
            isEdit = false
        }
        else if isEdit == nil {
            isEdit = true
        }

        space?.username = userNameRow.value
        space?.password = secretKeyRow.value

        super.connect()
    }


    // MARK: ScrapedDelegate

    func scraped(accessKey: String, secretKey: String) {
        navigationController?.popToViewController(self, animated: true)

        DispatchQueue.main.async {
            self.userNameRow.value = accessKey
            self.userNameRow.updateCell()

            self.secretKeyRow.value = secretKey
            self.secretKeyRow.updateCell()

            self.form.validate()
        }
    }


    // MARK: Private Methods

    private func enableConnect(_ cell: AccountCell? = nil, _ row: AccountRow? = nil) {
        navigationItem.rightBarButtonItem?.isEnabled = userNameRow.isValid
            && secretKeyRow.isValid
    }
}

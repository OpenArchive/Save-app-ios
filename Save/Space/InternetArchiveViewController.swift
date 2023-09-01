//
//  InternetArchiveViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import CleanInsightsSDK

class InternetArchiveViewController: BaseServerViewController, ScrapeDelegate {

    static let keysUrl = URL(string: "https://archive.org/account/s3.php")!

    private let secretKeyRow = AccountRow() {
        $0.title = NSLocalizedString("Secret Key", comment: "")
        $0.placeholder = NSLocalizedString("Required", comment: "")
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Internet Archive", comment: "")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: space != nil
                ? NSLocalizedString("Done", comment: "")
                : NSLocalizedString("Connect", comment: ""),
            style: .done, target: self,
            action: #selector(connect))

        favIconRow.value = IaSpace.favIcon
        userNameRow.title = NSLocalizedString("Access Key", comment: "")
        userNameRow.value = space?.username
        secretKeyRow.value = space?.password

        let actionSection = Section()

        form
            +++ favIconRow

            <<< userNameRow.cellUpdate(enableConnect(_:_:))

            <<< secretKeyRow.cellUpdate(enableConnect(_:_:))

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
                $0.cell.textLabel?.adjustsFontForContentSizeCategory = true

                let appName = Bundle.main.displayName

                $0.title = String(format: NSLocalizedString("%@ needs your Internet Archive account's API keys to be able to upload to it.", comment: ""), appName)
                    + "\n\n"
                    + String(format: NSLocalizedString("You can let %1$@ try to acquire these keys automatically, or you can tap this row which will send you to %2$@ in Safari from where you can copy-and-paste these keys manually.", comment: ""), appName, InternetArchiveViewController.keysUrl.absoluteString)
                    + "\n\n"
                    + String(format: NSLocalizedString("When using the \"%1$@\" feature, make sure to log in and then touch the \"Refresh\" button in the top right to let %2$@ have another try at automatically scraping the keys.", comment: ""), NSLocalizedString("Acquire Keys", comment: ""), appName)
                }
                .onCellSelection() { _, _ in
                    UIApplication.shared.open(InternetArchiveViewController.keysUrl, options: [:])
            }

            +++ actionSection

            <<< ButtonRow() {
                $0.title = NSLocalizedString("Acquire Keys", comment: "")
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

            CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: space?.name)
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

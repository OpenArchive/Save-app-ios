//
//  InternetArchiveViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class InternetArchiveViewController: BaseServerViewController {

    private static let keysUrl = URL(string: "http://archive.org/account/s3.php")!

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

        form
            +++ favIconRow

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.title = "Please go to % and copy the displayed access and secret keys into the provided fields!".localize(value: InternetArchiveViewController.keysUrl.absoluteString)
            }
            .onCellSelection() { _, _ in
                UIApplication.shared.open(InternetArchiveViewController.keysUrl, options: [:])
            }

            <<< userNameRow.cellUpdate(enableConnect(_:_:))

            <<< secretKeyRow.cellUpdate(enableConnect(_:_:))

            // To get another divider after the last row.
            <<< LabelRow()

        if space != nil {
            form
                +++ removeRow
        }

        form.validate()
        enableConnect()
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


    // MARK: Private Methods

    private func enableConnect(_ cell: AccountCell? = nil, _ row: AccountRow? = nil) {
        navigationItem.rightBarButtonItem?.isEnabled = userNameRow.isValid
            && secretKeyRow.isValid
    }
}

//
//  InternetArchiveViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class InternetArchiveViewController: FormViewController {

    var space: IaSpace?

    private static let keysUrl = URL(string: "http://archive.org/account/s3.php")!

    private let favIconRow = AvatarRow() {
        $0.disabled = true
        $0.value = IaSpace.favIcon
    }

    private let accessKeyRow = AccountRow() {
        $0.title = "Access Key".localize()
        $0.add(rule: RuleRequired())
    }

    private let secretKeyRow = AccountRow() {
        $0.title = "Secret Key".localize()
        $0.add(rule: RuleRequired())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Internet Archive".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Connect".localize(), style: .done, target: self,
            action: #selector(connect))

        accessKeyRow.value = space?.username
        secretKeyRow.value = space?.password

        form
            +++ Section()

            <<< favIconRow

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.title = "Please go to % and copy the displayed access and secret keys into the provided fields!".localize(value: InternetArchiveViewController.keysUrl.absoluteString)
            }
            .onCellSelection() { _, _ in
                UIApplication.shared.open(InternetArchiveViewController.keysUrl, options: [:])
            }

            <<< accessKeyRow.cellUpdate(enableConnect(_:_:))

            <<< secretKeyRow.cellUpdate(enableConnect(_:_:))

        form.validate()
        enableConnect()
    }


    // MARK: Actions

    @objc func connect() {
        let space = self.space ?? IaSpace()

        space.username = accessKeyRow.value
        space.password = secretKeyRow.value

        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(space, forKey: space.id,
                                  inCollection: Space.collection)
        }

        navigationController?.popViewController(animated: true)

        // If OnboardingViewController called us, let it know, that the
        // user created a space successfully.
        if let onboardingVc = self.navigationController?.topViewController as? OnboardingViewController {
            onboardingVc.spaceCreated = true
        }
    }


    // MARK: Private Methods

    private func enableConnect(_ cell: AccountCell? = nil, _ row: AccountRow? = nil) {
        navigationItem.rightBarButtonItem?.isEnabled = accessKeyRow.isValid
            && secretKeyRow.isValid
    }
}

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

    private static let keysUrl = URL(string: "http://archive.org/account/s3.php")!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Internet Archive".localize()

        form
            +++ Section()
            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.title = "Please go to % and copy the displayed access and secret keys into the provided fields!".localize(value: InternetArchiveViewController.keysUrl.absoluteString)
            }
            .onCellSelection() { _, _ in
                UIApplication.shared.open(InternetArchiveViewController.keysUrl, options: [:])
            }

            <<< AccountRow() {
                $0.title = "Access Key".localize()
                $0.value = InternetArchive.accessKey
                $0.add(rule: RuleRequired())
            }
            .onChange() { row in
                InternetArchive.accessKey = row.value
            }

            <<< AccountRow() {
                $0.title = "Secret Key".localize()
                $0.value = InternetArchive.secretKey
                $0.add(rule: RuleRequired())
            }
            .onChange() { row in
                InternetArchive.secretKey = row.value
            }
    }
}

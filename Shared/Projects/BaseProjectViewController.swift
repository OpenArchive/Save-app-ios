//
//  BaseProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class BaseProjectViewController: FormViewController {

    var project: Project

    let nameRow = TextRow() {
        $0.placeholder = "Name your project".localize()
        $0.add(rule: RuleRequired())
    }


    init(_ project: Project) {
        self.project = project

        super.init()
    }

    required init?(coder decoder: NSCoder) {
        project = decoder.decodeObject() as! Project

        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        form.validate()
        enableDone()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: Actions

    @objc func connect() {
        project.name = nameRow.value

        store()

        // Only animate, if we don't have a delegate: Too much pop animations
        // will end in the last view controller not being popped and it's also
        // too much going on in the UI.
        navigationController?.popViewController(animated: delegate == nil)

        // Could be PrivateServerViewController or InternetArchiveViewController
        // in the onboarding flow / create space flow to ensure a space and
        // project exits.
        delegate?.done()
    }


    // MARK: Private Methods

    func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = nameRow.isValid
    }

    func store() {
        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(self.project, forKey: self.project.id,
                                  inCollection: Project.collection)
        }
    }
}

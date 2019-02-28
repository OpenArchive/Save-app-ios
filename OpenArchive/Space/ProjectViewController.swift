//
//  ProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class ProjectViewController: FormViewController {

    private var project: Project

    private let nameRow = TextRow() {
        $0.title = "Name".localize()
        $0.add(rule: RuleRequired())
    }

    init(_ project: Project? = nil) {
        self.project = project ?? Project(space: SelectedSpace.space)

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        project = aDecoder.decodeObject() as! Project

        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "New Project".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(connect))

        nameRow.value = project.name

        form
            +++ Section()

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.textAlignment = .center
                $0.title = "Curate your own project or browse for an existing one.".localize()
            }

            <<< nameRow.cellUpdate() { _, _ in
                self.enableDone()
            }

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

        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(self.project, forKey: self.project.id,
                                  inCollection: Project.collection)
        }

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

    private func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = nameRow.isValid
    }
}

//
//  FoldersViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 30.10.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import YapDatabase

class FoldersViewController: FormViewController {

    private let archived: Bool

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings = YapDatabaseViewMappings(
        groups: ProjectsView.groups, view: ProjectsView.name)

    private var projectsSection: Section?

    private var hasArchived = false

    private let cc = CcSelector(individual: false)


    override init() {
        archived = false

        super.init()
    }

    init(archived: Bool) {
        self.archived = archived

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        archived = aDecoder.decodeBool(forKey: "archived")

        super.init(coder: aDecoder)
    }

    override func encode(with coder: NSCoder) {
        coder.encode(archived, forKey: "archived")

        super.encode(with: coder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = archived
            ? NSLocalizedString("Archived Folders", comment: "")
            : NSLocalizedString("Folders", comment: "")

        if archived {
            form
            +++ Section("")

            projectsSection = form.last
        }
        else {
            cc.set(SelectedSpace.space?.license)

            form
            +++ Section("")

            <<< cc.ccSw.onChange(ccLicenseChanged)

            <<< cc.remixSw.onChange(ccLicenseChanged)

            <<< cc.shareAlikeSw.onChange(ccLicenseChanged)

            <<< cc.commercialSw.onChange(ccLicenseChanged)

            <<< cc.licenseRow

            <<< cc.learnMoreRow

            +++ Section("")

            projectsSection = form.last

            form
            +++ Section("")
            <<< ButtonRow("archived") {
                $0.title = NSLocalizedString("View Archived Folders", comment: "")

                $0.presentationMode = .show(controllerProvider: .callback(builder: {
                    FoldersViewController(archived: true)
                }), onDismiss: nil)

                $0.hidden = Condition.function(["archived"], { [weak self] _ in
                    !(self?.hasArchived ?? false)
                })
            }
        }

        Db.add(observer: self, #selector(yapDatabaseModified))

        projectsReadConn?.update(mappings: projectsMappings)

        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: Private Methods

    @objc
    private func yapDatabaseModified(_ notification: Notification) {
        if projectsReadConn?.hasChanges(projectsMappings) ?? false {
            reload()
        }
    }

    private func reload() {
        projectsSection?.removeAll()


        let projects: [Project] = projectsReadConn?.objects(in: 0, with: projectsMappings) ?? []

        hasArchived = !archived && projects.contains(where: { !$0.active })

        for project in projects.filter({ archived != $0.active }) {
            projectsSection!
            <<< ButtonRow {
                $0.title = project.name
                $0.presentationMode = .show(controllerProvider: .callback(builder: {
                    EditFolderViewController(project)
                }), onDismiss: nil)
            }
        }

        if archived && (projectsSection?.isEmpty ?? true) {
            navigationController?.popViewController(animated: true)
        }

        form.rowBy(tag: "archived")?.evaluateHidden()
    }


    // MARK: Private Methods

    private func ccLicenseChanged(_ row: SwitchRow) {
        guard let space = SelectedSpace.space else {
            _ = cc.get()

            return
        }

        space.license = cc.get()

        Db.writeConn?.asyncReadWrite { tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)

            let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }

            for project in projects {
                project.license = space.license

                tx.setObject(project)
            }
        }
    }
}

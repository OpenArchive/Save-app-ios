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
            +++ Section(NSLocalizedString("Archived Folders", comment: ""))
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

            +++ Section(NSLocalizedString("Active Folders", comment: ""))
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
        if let notifications = projectsReadConn?.beginLongLivedReadTransaction(),
           let viewConn = projectsReadConn?.ext(ProjectsView.name) as? YapDatabaseViewConnection,
           !projectsMappings.isNextSnapshot(notifications) || viewConn.hasChanges(for: notifications)
        {
            projectsReadConn?.update(mappings: projectsMappings)

            reload()
        }
    }

    private func reload() {
        projectsSection?.removeAll()

        hasArchived = false

        projectsReadConn?.readInView(projectsMappings.view, { viewTransaction, transaction in
            viewTransaction?.iterateKeysAndObjects(inGroup: projectsMappings.group(forSection: 0)!, using: {
                collection, key, object, index, stop in

                guard let project = object as? Project else {
                    return
                }

                if !archived && !project.active {
                    hasArchived = true
                }

                guard archived != project.active else {
                    return
                }

                projectsSection!
                <<< ButtonRow {
                    $0.title = project.name
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        EditProjectViewController(project)
                    }), onDismiss: nil)
                }
            })
        })

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

        Db.writeConn?.asyncReadWrite { transaction in
            transaction.setObject(space, forKey: space.id, inCollection: Space.collection)

            var changed = [Project]()

            transaction.iterateKeysAndObjects(inCollection: Project.collection) { (key, project: Project, stop) in
                if project.active && project.spaceId == space.id {
                    project.license = space.license
                    changed.append(project)
                }
            }

            for project in changed {
                transaction.setObject(project, forKey: project.id, inCollection: Project.collection)
            }
        }
    }
}

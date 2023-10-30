//
//  FoldersViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 30.10.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class FoldersViewController: FormViewController {

    private let archived: Bool


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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        var activeProjects = [Project]()
        var archivedProjects = [Project]()

        Db.newLongLivedReadConn()?.read({ transaction in
            transaction.iterateKeysAndObjects(inCollection: Project.collection) { (key, project: Project, stop) in
                if project.active {
                    activeProjects.append(project)
                }
                else {
                    archivedProjects.append(project)
                }
            }
        })

        form.removeAll()

        if archived && archivedProjects.isEmpty {
            navigationController?.popViewController(animated: animated)

            return
        }


        if archived {
            form
            +++ Section(NSLocalizedString("Archived Folders", comment: ""))
            +++ Section("")

            add(projects: archivedProjects)
        }
        else {
            form
            +++ Section("")
            <<< SwitchRow {
                $0.title = NSLocalizedString("Set the same Creative Commons license for ALL folders on this server.", comment: "")

                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.switchControl.onTintColor = .accent
            }

            +++ Section(NSLocalizedString("Active Folders", comment: ""))
            +++ Section("")

            add(projects: activeProjects)

            if !archivedProjects.isEmpty {
                form
                +++ Section("")
                <<< ButtonRow {
                    $0.title = NSLocalizedString("View Archived Folders", comment: "")
                    $0.presentationMode = .show(controllerProvider: .callback(builder: {
                        FoldersViewController(archived: true)
                    }), onDismiss: nil)
                }
            }
        }
    }

    private func add(projects: [Project]) {
        for project in projects {
            form.last!
            <<< ButtonRow {
                $0.title = project.name
                $0.presentationMode = .show(controllerProvider: .callback(builder: {
                    EditProjectViewController(project)
                }), onDismiss: nil)
            }
        }
    }
}

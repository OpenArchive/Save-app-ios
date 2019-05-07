//
//  MenuViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Localize
import YapDatabase

class MenuViewController: TableWithSpacesViewController {

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings = YapDatabaseViewMappings(groups:
        ProjectsView.groups, view: ProjectsView.name)

    private var projectsCount: Int {
        return Int(projectsMappings.numberOfItems(inSection: 0))
    }

    /**
     Remove action for table list row. Deletes a space.
     */
    private lazy var removeAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Remove".localize())
        { (action, indexPath) in

            if let project = self.getProject(indexPath) {
                self.present(RemoveProjectAlert(project), animated: true)
            }

            self.tableView.setEditing(false, animated: true)
        }

        return action
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        projectsReadConn?.update(mappings: projectsMappings)

        allowAdd = true

        tableView.separatorStyle = .none

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModifiedExternally, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        tableView.reloadData()

        if SelectedSpace.id == nil {
            performSegue(withIdentifier: "connectSpaceSegue", sender: self)
        }
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return projectsCount
        case 2:
            return 1
        case 3:
            return 2
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                return SpacesListCell.height
            }
            else if indexPath.row == 1 {
                return SelectedSpaceCell.height
            }
        }

        return MenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0,
                let cell = getSpacesListCell() {

                return cell
            }
            else if indexPath.row == 1,
                let cell = getSelectedSpaceCell() {
                cell.accessoryType = .disclosureIndicator

                return cell
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell
        
        switch indexPath.section {
        case 1:
            return cell.set(Project.getName(getProject(indexPath)), accessoryType: .disclosureIndicator)

        case 2:
            return cell.set("Data Usage".localize(), accessoryType: .disclosureIndicator)

        case 3:
            switch indexPath.row {
            case 0:
                return cell.set("About \(Bundle.main.displayName)".localize(), accessoryType: .disclosureIndicator)
            default:
                return cell.set("Privacy Policy".localize(), accessoryType: .disclosureIndicator)
            }

        default:
            return cell.set("")
        }
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> TableHeader {
        let header = super.tableView(tableView, viewForHeaderInSection: section)

        switch section {
        case 1:
            header.label.text = "Project Settings".localize().localizedUppercase
        case 2:
            header.label.text = "App Settings".localize().localizedUppercase
        case 3:
            header.label.text = "Info".localize().localizedUppercase
        default:
            header.label.text = nil
        }

        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? TableHeader.reducedHeight : TableHeader.height
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row < projectsCount
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [removeAction]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vc: UIViewController?

        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                vc = SpaceViewController()
            }

        case 1:
            vc = EditProjectViewController(getProject(indexPath)!)

        case 2:
            vc = DataUsageViewController()

        default:
            break
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Shall be called, when something changes the database.
     */
    @objc override func yapDatabaseModified(notification: Notification) {
        super.yapDatabaseModified(notification: notification)

        guard let notifications = projectsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = projectsReadConn?.ext(ProjectsView.name) as? YapDatabaseViewConnection else {
                return
        }

        if !viewConn.hasChanges(for: notifications) {
            projectsReadConn?.update(mappings: projectsMappings)

            return
        }

        var changes = NSArray()

        viewConn.getSectionChanges(nil, rowChanges: &changes,
                                   for: notifications, with: projectsMappings)

        if let changes = changes as? [YapDatabaseViewRowChange],
            changes.count > 0 {

            tableView.beginUpdates()

            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath {
                        tableView.deleteRows(at: [transform(indexPath)], with: .automatic)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath {
                        tableView.insertRows(at: [transform(newIndexPath)], with: .automatic)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                        tableView.moveRow(at: transform(indexPath), to: transform(newIndexPath))
                    }
                case .update:
                    if let indexPath = change.indexPath {
                        tableView.reloadRows(at: [transform(indexPath)], with: .none)
                    }
                @unknown default:
                    break
                }
            }

            tableView.endUpdates()
        }
    }


    // MARK: Private Methods

    private func getProject(_ indexPath: IndexPath) -> Project? {
        var project: Project?

        projectsReadConn?.read() { transaction in
            project = (transaction.ext(ProjectsView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(indexPath.row), inSection: 0, with: self.projectsMappings) as? Project
        }

        return project
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: 1)
    }
}

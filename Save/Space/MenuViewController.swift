//
//  MenuViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
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
            title: NSLocalizedString("Remove", comment: ""))
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

        navigationItem.title = NSLocalizedString("Menu", comment: "")

        projectsReadConn?.update(mappings: projectsMappings)

        allowAdd = true

        tableView.separatorStyle = .none

        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        tableView.reloadData()
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
            return 2
        case 3:
            return 3
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
            switch indexPath.row {
            case 0:
                return cell.set(NSLocalizedString("Data Usage", comment: ""), accessoryType: .disclosureIndicator)
            default:
                return cell.set(NSLocalizedString("Miscellaneous", comment: ""), accessoryType: .disclosureIndicator)
            }

        case 3:
            switch indexPath.row {
            case 0:
                return cell.set(String(format: NSLocalizedString("About %@", comment: ""), Bundle.main.displayName), accessoryType: .disclosureIndicator)
            case 1:
                return cell.set(NSLocalizedString("Privacy Policy", comment: ""), accessoryType: .disclosureIndicator)
            default:
                cell.set(String(format: "%@ %@ (%@)", Bundle.main.displayName, Bundle.main.version, Bundle.main.build), textColor: .lightGray)

                cell.selectionStyle = .none
                cell.label.font = cell.label.font.withSize(UIFont.montserrat(forTextStyle: .footnote)?.pointSize ?? 13)

                return cell
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
            header.label.text = NSLocalizedString("Project Settings", comment: "").localizedUppercase
        case 2:
            header.label.text = NSLocalizedString("App Settings", comment: "").localizedUppercase
        case 3:
            header.label.text = NSLocalizedString("Info", comment: "").localizedUppercase
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
            if let project = getProject(indexPath) {
                vc = EditProjectViewController(project)
            }

        case 2:
            switch indexPath.row {
            case 0:
                vc = DataUsageViewController()

            default:
                vc = MiscSettingsViewController()
            }

        case 3:
            if indexPath.row == 0 {
                if let url = URL(string: "https://open-archive.org/about") {
                    UIApplication.shared.open(url, options: [:])
                }
            }
            if indexPath.row == 1 {
                if let url = URL(string: "https://open-archive.org/privacy") {
                    UIApplication.shared.open(url, options: [:])
                }
            }

        default:
            break
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK: Actions

    @IBAction func done() {
        dismiss(animated: true)
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

        if !projectsMappings.isNextSnapshot(notifications) || !viewConn.hasChanges(for: notifications) {
            projectsReadConn?.update(mappings: projectsMappings)

            tableView.reloadSections([1], with: .automatic)

            return
        }

        let (_, changes) = viewConn.getChanges(forNotifications: notifications, withMappings: projectsMappings)

        // Don't update table if it's not currently in the view hierarchy.
        if changes.count > 0 && tableView.window != nil {

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

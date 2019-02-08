//
//  MyAccountViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Localize
import YapDatabase

class MyAccountViewController: BaseTableViewController {

    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(
            groups: SpacesProjectsView.groups,
            view: SpacesProjectsView.name)

        readConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private var spacesCount: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    private var projectsCount: Int {
        return Int(mappings.numberOfItems(inSection: 1))
    }

    /**
     Delete action for table list row. Deletes a space.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let message: String
            let title: String
            let handler: AlertHelper.ActionHandler

            if indexPath.section == 1 {
                let server: String

                if indexPath.row < self.spacesCount {
                    let space = self.getSpace(indexPath)
                    server = space?.prettyName ?? WebDavServer.PRETTY_NAME

                    handler = { _ in
                        if let key = space?.id {
                            Db.writeConn?.asyncReadWrite() { transaction in
                                transaction.removeObject(forKey: key, inCollection: Space.collection)
                            }
                        }
                    }
                }
                else {
                    server = InternetArchive.PRETTY_NAME
                    handler = { _ in
                        InternetArchive.accessKey = nil
                        InternetArchive.secretKey = nil

                        self.tableView.reloadData()
                    }
                }

                title = "Delete Space".localize()
                message = "Are you sure you want to delete your space \"%\"?".localize(value: server)
            }
            else {
                title = "Delete Project".localize()
                let project = self.getProject(indexPath)
                message = "Are you sure you want to delete your project \"%\"?".localize(value: project?.name ?? "")
                handler = { _ in
                    if let key = project?.id {
                        Db.writeConn?.asyncReadWrite() { transaction in
                            transaction.removeObject(forKey: key, inCollection: Project.collection)
                        }
                    }
                }
            }

            AlertHelper.present(
                self, message: message,
                title: title, actions: [
                    AlertHelper.cancelAction(),
                    AlertHelper.destructiveAction("Delete".localize(), handler: handler)
                ])

            self.tableView.setEditing(false, animated: true)
        }

        return action
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModified),
                                               name: .YapDatabaseModified,
                                               object: readConn?.database)
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
            return 1
        case 1:
            return spacesCount + 2
        case 2:
            return projectsCount + 2
        case 3:
            return 3
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return ProfileCell.height
        }

        return MenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.reuseId, for: indexPath) as? ProfileCell {

            return cell.set()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell
        
        switch indexPath.section {
        case 1:
            if indexPath.row < spacesCount {
                return cell.set(getSpace(indexPath)?.prettyName ?? WebDavServer.PRETTY_NAME)
            }
            else if indexPath.row == spacesCount {
                return cell.set("Private Server".localize(), isPlaceholder: true)
            }

            return cell.set("Internet Archive".localize(), isPlaceholder: !InternetArchive.isAvailable)
        case 2:
            if indexPath.row < projectsCount {
                return cell.set(getProject(indexPath)?.name ?? "Unnamed Project".localize())
            }
            else if indexPath.row == projectsCount {
                return cell.set("Create New Project".localize(), isPlaceholder: true)
            }

            return cell.set("Browse".localize(), UIColor.accent, true)
        case 3:
            cell.addIndicator.isHidden = true
            switch indexPath.row {
            case 0:
                return cell.set("Data Use".localize())
            case 1:
                return cell.set("Privacy".localize())
            default:
                return cell.set("About".localize())
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
            header.text = "Spaces".localize()
        case 2:
            header.text = "Projects".localize()
        case 3:
            header.text = "Settings".localize()
        default:
            break
        }

        return header
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return (
            indexPath.section == 1
            && (
                indexPath.row < spacesCount
                || (indexPath.row > spacesCount && InternetArchive.isAvailable)
            )
        )
        || (indexPath.section == 2 && indexPath.row < projectsCount)
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vc: UIViewController?

        switch indexPath.section {
        case 0:
            vc = EditProfileViewController()
        case 1:
            if indexPath.row < spacesCount {
                let psvc = PrivateServerViewController()
                psvc.space = getSpace(indexPath)
                vc = psvc
            }
            else if indexPath.row == spacesCount {
                vc = PrivateServerViewController()
            }
            else {
                vc = InternetArchiveViewController()
            }
        case 2:
            if indexPath.row < projectsCount {
                vc = ProjectViewController(getProject(indexPath)!)
            }
            else if indexPath.row == projectsCount {
                vc = ProjectViewController()
            }
            else {
                performSegue(withIdentifier: "browseSegue", sender: self)
            }
        default:
            break
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK:

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let browseVc = segue.destination as? BrowseViewController {
            browseVc.space = getSpace(IndexPath(row: 0, section: 1))
        }
    }
    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if let readConn = readConn {
            var changes = NSArray()

            (readConn.ext(SpacesProjectsView.name) as? YapDatabaseViewConnection)?
                .getSectionChanges(nil,
                                   rowChanges: &changes,
                                   for: readConn.beginLongLivedReadTransaction(),
                                   with: mappings)

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
                    }
                }

                tableView.endUpdates()
            }
        }
    }


    // MARK: Private Methods

    private func getItem(_ indexPath: IndexPath) -> Any? {
        var item: Any?

        readConn?.read() { transaction in
            item = (transaction.ext(SpacesProjectsView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(indexPath.row), inSection: UInt(indexPath.section - 1), with: self.mappings)
        }

        return item
    }

    private func getSpace(_ indexPath: IndexPath) -> Space? {
        return getItem(indexPath) as? Space
    }

    private func getProject(_ indexPath: IndexPath) -> Project? {
        return getItem(indexPath) as? Project
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: indexPath.section + 1)
    }
}

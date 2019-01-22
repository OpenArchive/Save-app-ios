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

class MyAccountViewController: UITableViewController {

    private lazy var readConn: YapDatabaseConnection? = {
        let conn = Db.newConnection()
        conn?.beginLongLivedReadTransaction()

        return conn
    }()

    private lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: [ServerConfig.COLLECTION], view: ServerConfig.COLLECTION)

        readConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private var serverConfigCount: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    private lazy var writeConn = Db.newConnection()

    /**
     Delete action for table list row. Deletes a space.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let server: String
            let handler: ((UIAlertAction) -> Void)

            if indexPath.row < self.serverConfigCount {
                let conf = self.getServerConfig(indexPath)
                server = conf?.prettyName ?? WebDavServer.PRETTY_NAME

                handler = { _ in

                    if let key = conf?.url?.absoluteString {
                        self.writeConn?.asyncReadWrite() { transaction in
                            transaction.removeObject(forKey: key, inCollection: ServerConfig.COLLECTION)
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

            AlertHelper.present(
                self, message: "Are you sure you want to delete your % credentials?".localize(value: server),
                title: "Delete Credentials".localize(), actions: [
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

        tableView.register(TableHeader.self, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)
        tableView.register(ProfileCell.nib, forCellReuseIdentifier: ProfileCell.reuseId)
        tableView.register(MenuItemCell.nib, forCellReuseIdentifier: MenuItemCell.reuseId)

        tableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
            return serverConfigCount + 2
        case 2:
            return 1
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

        if let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as? MenuItemCell {
            switch indexPath.section {
            case 1:
                if indexPath.row < serverConfigCount {
                    cell.set(getServerConfig(indexPath)?.prettyName ?? WebDavServer.PRETTY_NAME)
                }
                else if indexPath.row == serverConfigCount {
                    cell.set("Private Server".localize(), isPlaceholder: true)
                }
                else {
                    cell.set("Internet Archive".localize(), isPlaceholder: !InternetArchive.isAvailable)
                }
            case 2:
                switch indexPath.row {
                case 0:
                    cell.set("Create New Project".localize(), isPlaceholder: true)
                default:
                    cell.set("")
                }
            case 3:
                cell.addIndicator.isHidden = true
                switch indexPath.row {
                case 0:
                    cell.set("Data Use".localize())
                case 1:
                    cell.set("Privacy".localize())
                default:
                    cell.set("About".localize())
                }
            default:
                cell.set("")
            }

            return cell
        }


        return UITableViewCell()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId) as? TableHeader {
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

        return nil
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && (
            indexPath.row < serverConfigCount
            || (indexPath.row > serverConfigCount && InternetArchive.isAvailable)
        )
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
            if indexPath.row < serverConfigCount {
                let psvc = PrivateServerViewController()
                psvc.conf = getServerConfig(indexPath)
                vc = psvc
            }
            else if indexPath.row == serverConfigCount {
                vc = PrivateServerViewController()
            }
            else {
                vc = InternetArchiveViewController()
            }
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
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if let readConn = readConn {
            var changes = NSArray()

            (readConn.ext(ServerConfig.COLLECTION) as? YapDatabaseViewConnection)?
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

    private func getServerConfig(_ indexPath: IndexPath) -> ServerConfig? {
        let ip = IndexPath(row: indexPath.row, section: 0)

        var conf: ServerConfig?

        readConn?.read() { transaction in
            conf = (transaction.ext(ServerConfig.COLLECTION) as? YapDatabaseViewTransaction)?
                .object(at: ip, with: self.mappings) as? ServerConfig
        }

        return conf
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: 1)
    }
}

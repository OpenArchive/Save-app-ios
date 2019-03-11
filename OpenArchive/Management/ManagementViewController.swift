//
//  ManagementViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class ManagementViewController: BaseTableViewController {

    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: AssetsView.groups,
                                               view: AssetsView.name)

        readConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    /**
     Delete action for table list row. Deletes an asset.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let title = "Delete Asset".localize()
            let asset = self.getAsset(indexPath)
            let message = "Are you sure you want to delete \"%\"?".localize(value: asset?.filename ?? "")
            let handler: AlertHelper.ActionHandler = { _ in
                if let key = asset?.id {
                    Db.writeConn?.asyncReadWrite() { transaction in
                        transaction.removeObject(forKey: key, inCollection: Asset.collection)
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

        let title = MultilineTitle()
        title.title.text = "Waiting…".localize()
        title.subtitle.text = "No Connection".localize()

        navigationItem.titleView = title

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                       name: .YapDatabaseModifiedExternally, object: nil)
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return AssetCell.height
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return Int(mappings.numberOfItems(inSection: 0))
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AssetCell.reuseId, for: indexPath) as! AssetCell

        cell.asset = getAsset(indexPath)

        return cell
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        var changes = NSArray()

        (readConn?.ext(AssetsView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(nil,
                               rowChanges: &changes,
                               for: readConn?.beginLongLivedReadTransaction() ?? [],
                               with: mappings)

        if let changes = changes as? [YapDatabaseViewRowChange],
            changes.count > 0 {

            tableView.beginUpdates()

            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath {
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath {
                        tableView.insertRows(at: [newIndexPath], with: .automatic)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                        tableView.moveRow(at: indexPath, to: newIndexPath)
                    }
                case .update:
                    if let indexPath = change.indexPath {
                        tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }

            tableView.endUpdates()
        }
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        readConn?.beginLongLivedReadTransaction()

        readConn?.read { transaction in
            self.mappings.update(with: transaction)
            self.tableView.reloadData()
        }
    }


    // MARK: Private Methods

    private func getAsset(_ indexPath: IndexPath) -> Asset? {
        var asset: Asset?

        readConn?.read() { transaction in
            asset = (transaction.ext(AssetsView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(indexPath.row), inSection: 0, with: self.mappings) as? Asset
        }

        return asset
    }

}

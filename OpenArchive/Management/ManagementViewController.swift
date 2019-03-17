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

    var delegate: DoneDelegate?

    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: UploadsView.groups,
                                               view: UploadsView.name)

        readConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    /**
     Delete action for table list row. Deletes an upload.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let title = "Delete Upload".localize()
            let upload = self.getUpload(indexPath)
            let message = "Are you sure you want to delete \"%\"?".localize(value: upload.upload?.filename ?? "")
            let handler: AlertHelper.ActionHandler = { _ in
                if var k = Int(upload.key ?? "") {
                    Db.writeConn?.asyncReadWrite() { transaction in
                        var uploads = [Upload]()

                        // Load all uploads.
                        transaction.enumerateKeysAndObjects(inCollection: Upload.collection) { key, object, stop in
                            if let upload = object as? Upload {
                                uploads.append(upload)
                            }
                        }

                        uploads.remove(at: k)

                        // Rewrite new list of uploads.
                        var i = 0
                        for upload in uploads {
                            if i >= k {
                                transaction.setObject(upload, forKey: String(i), inCollection: Upload.collection)
                            }
                            i += 1
                        }

                        // Delete the last one.
                        transaction.removeObject(forKey: String(i), inCollection: Upload.collection)

                        if let assetId = upload.upload?.asset?.id {
                            transaction.removeObject(forKey: assetId, inCollection: Asset.collection)
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

            self.toggleEdit()
        }

        return action
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = "Waiting…".localize()
        title.subtitle.text = "No Connection".localize()

        navigationItem.titleView = title

        navigationItem.rightBarButtonItem = getButton()

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                       name: .YapDatabaseModifiedExternally, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        delegate?.done()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UploadCell.height
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UploadCell.reuseId, for: indexPath) as! UploadCell

        cell.upload = getUpload(indexPath).upload

        return cell
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }

    /**
     Reading all objects and rewriting them seems expensive, but is the best solution
     I could come up with when using YapDatabase.
    */
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        Db.writeConn?.asyncReadWrite { transaction in
            var uploads = [Upload]()

            transaction.enumerateKeysAndObjects(inCollection: Upload.collection) { key, object, stop in
                if let upload = object as? Upload {
                    uploads.append(upload)
                }
            }

            uploads.insert(uploads.remove(at: fromIndexPath.row), at: to.row)

            var i = 0
            for upload in uploads {
                transaction.setObject(upload, forKey: String(i), inCollection: Upload.collection)
                i += 1
            }
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        var changes = NSArray()

        (readConn?.ext(UploadsView.name) as? YapDatabaseViewConnection)?
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
        }

        tableView.reloadData()
    }


    // MARK: Private Methods

    @objc private func toggleEdit() {
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)

            navigationItem.rightBarButtonItem = getButton()
        }
        else {
            tableView.setEditing(true, animated: true)

            navigationItem.rightBarButtonItem = getButton(type: .done)
        }
    }

    private func getButton(type: UIBarButtonItem.SystemItem = .edit) -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: type, target: self, action: #selector(toggleEdit))
    }

    private func getUpload(_ indexPath: IndexPath) -> (key: String?, upload: Upload?) {
        var key = NSString()
        var upload: Upload?

        readConn?.read() { transaction in
            if let vt = transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction {
                let pointer: AutoreleasingUnsafeMutablePointer<NSString?>
                    = AutoreleasingUnsafeMutablePointer<NSString?>.init(&key)

                vt.getKey(pointer, collection: nil, at: indexPath, with: self.mappings)

                upload = vt.object(at: indexPath, with: self.mappings) as? Upload
            }
        }

        return (key as String, upload)
    }
}

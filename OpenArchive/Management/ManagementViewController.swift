//
//  ManagementViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import DownloadButton

class ManagementViewController: BaseTableViewController, UploadCellDelegate {

    var delegate: DoneDelegate?

    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings = YapDatabaseViewMappings(
        groups: UploadsView.groups, view: UploadsView.name)

    private var count: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    private var isDirectEdit = false

    /**
     Delete action for table list row. Deletes an upload.
     */
    private lazy var removeAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Remove".localize())
        { action, indexPath in
            guard let upload = self.getUpload(indexPath) else {
                return
            }

            if !self.isDirectEdit {
                upload.remove()

                return
            }

            AlertHelper.present(
                self, message: "Are you sure you want to remove \"%\"?".localize(value: upload.filename),
                title: "Remove Upload".localize(),
                actions: [
                    AlertHelper.cancelAction(),
                    AlertHelper.destructiveAction("Remove Upload".localize(), handler: { _ in
                        upload.remove()
                    })
                ])
        }

        return action
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        readConn?.update(mappings: mappings)

        updateTitle()
        setButton()

        Db.add(observer: self, #selector(yapDatabaseModified))
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
        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UploadCell.reuseId, for: indexPath) as! UploadCell

        cell.upload = getUpload(indexPath)
        cell.delegate = self

        return cell
    }

    override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        isDirectEdit = true
    }

    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        isDirectEdit = false
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [removeAction]
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if let upload = getUpload(indexPath) {
            return upload.state == .pending || upload.state == .startDownload
        }

        return false
    }

    /**
     Reading all objects and rewriting them seems expensive, but is the best solution
     I could come up with when using YapDatabase.
    */
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        Db.writeConn?.asyncReadWrite { transaction in
            var uploads = [Upload]()

            (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .enumerateKeysAndObjects(inGroup: UploadsView.groups[0])
                { collection, key, object, index, stop in
                    if let upload = object as? Upload {
                        uploads.append(upload)
                    }
            }

            uploads.insert(uploads.remove(at: fromIndexPath.row), at: to.row)

            var i = 0
            for upload in uploads {
                if upload.order != i {
                    upload.order = i
                    transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                }

                i += 1
            }
        }
    }


    // MARK: UploadCellDelegate

    func progressTapped(_ upload: Upload, _ button: PKDownloadButton) {
        switch button.state {
        case .startDownload:
            NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
        case .pending, .downloading:
            NotificationCenter.default.post(name: .uploadManagerPause, object: upload.id)
        case .downloaded:
            break
        @unknown default:
            break
        }
    }

    func showError(_ upload: Upload) {
        AlertHelper.present(
            self, message: upload.error,
            title: "Multiple attempts with no success".localize(),
            actions: [
                AlertHelper.destructiveAction("Remove".localize(), handler: { _ in
                    upload.remove()
                }),
                AlertHelper.defaultAction("Retry".localize(), handler: { _ in
                    NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
                }),
                AlertHelper.cancelAction()])
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        guard let notifications = readConn?.beginLongLivedReadTransaction(),
            let viewConn = readConn?.ext(UploadsView.name) as? YapDatabaseViewConnection else {
                return
        }

        if !viewConn.hasChanges(for: notifications) {
            readConn?.update(mappings: mappings)

            return
        }

        var changes = NSArray()

        viewConn.getSectionChanges(nil, rowChanges: &changes,
                                   for: notifications, with: mappings)

        if let changes = changes as? [YapDatabaseViewRowChange],
            changes.count > 0 {

            tableView.beginUpdates()

            // NOTE: Sections other than 0 are ignored, because `UploadsView`
            // also tracks changes in `Asset`s, so `UploadManager` can update
            // its referenced assets, when their status changes.
            // (Needed, when movie import takes longer as the user hits upload.)

            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath, indexPath.section == 0 {
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath, newIndexPath.section == 0 {
                        tableView.insertRows(at: [newIndexPath], with: .automatic)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath,
                        indexPath.section == 0 && newIndexPath.section == 0 {
                        tableView.reloadRows(at: [indexPath, newIndexPath], with: .none)
                    }
                case .update:
                    if let indexPath = change.indexPath, indexPath.section == 0 {
                        tableView.reloadRows(at: [indexPath], with: .none)
                    }
                @unknown default:
                    break
                }
            }

            tableView.endUpdates()

            updateTitle()
            setButton()
        }
    }


    // MARK: Private Methods

    private func updateTitle() {
        let titleView = navigationItem.titleView as? MultilineTitle ?? MultilineTitle()
        let count = self.count
        var uploading = false

        for row in 0 ... count {
            if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? UploadCell,
                let state = cell.upload?.state,
                state == .pending || state == .downloading {

                uploading = true
                break
            }
        }

        titleView.title.text = count == 0 ? "Done".localize() : (uploading ? "Uploading…".localize() : "Waiting…".localize())
        titleView.subtitle.text = "% left".localize(value: Formatters.format(count))

        navigationItem.titleView = titleView
    }

    private func setButton() {
        if count > 0 {
            navigationItem.rightBarButtonItem = editButtonItem
        }
        else {
            navigationItem.rightBarButtonItem = nil
            tableView.setEditing(false, animated: true)
        }
    }

    private func getUpload(_ indexPath: IndexPath) -> Upload? {
        var upload: Upload?

        readConn?.read() { transaction in
            upload = (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Upload
        }

        return upload
    }
}

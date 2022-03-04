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
import CleanInsightsSDK

class ManagementViewController: BaseTableViewController, UploadCellDelegate, AnalyticsCellDelegate {

    var delegate: DoneDelegate?

    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings = YapDatabaseViewMappings(
        groups: UploadsView.groups, view: UploadsView.name)

    private var count: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

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

            upload.remove()
        }

        return action
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        readConn?.update(mappings: mappings)

        updateTitle()
        setButton()

        // This button says "Back" because we don't want to have 2 "Done" buttons,
        // when in editing mode.
        // That doesn't make too much sense on iPad, because we're displayed as a popover.
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = nil
        }

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
        if indexPath.section == 0 {
            return AnalyticsCell.height
        }

        return UploadCell.height
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            switch CleanInsights.shared.state(ofCampaign: "upload_fails") {
            case .unknown, .expired:
                return 1

            default:
                return 0
            }
        }

        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: AnalyticsCell.reuseId, for: indexPath) as! AnalyticsCell

            cell.delegate = self

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: UploadCell.reuseId, for: indexPath) as! UploadCell

        cell.upload = getUpload(indexPath)
        cell.delegate = self

        return cell
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return indexPath.section == 0 ? [] : [removeAction]
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        if editing {
            NotificationCenter.default.post(name: .uploadManagerPause, object: nil)
        }
        else {
            NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }

        return true
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }

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
                .iterateKeysAndObjects(inGroup: UploadsView.groups[0])
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
                    transaction.replace(upload, forKey: upload.id, inCollection: Upload.collection)
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


    // MARK: AnalyticsCellDelegate

    func analyticsReload() {
        tableView.reloadSections([0], with: .automatic)
    }

    func analyticsPresent(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }


    // MARK: Actions

    @IBAction func done() {
        if isEditing {
            NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
        }

        dismiss(animated: true)
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

        let (_, changes) = viewConn.getChanges(forNotifications: notifications, withMappings: mappings)

        if changes.count > 0 {
            tableView.beginUpdates()

            // NOTE: Sections other than 0 are ignored, because `UploadsView`
            // also tracks changes in `Asset`s, so `UploadManager` can update
            // its referenced assets, when their status changes.
            // (Needed, when movie import takes longer as the user hits upload.)

            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath, indexPath.section == 0 {
                        tableView.deleteRows(at: [transform(indexPath)], with: .fade)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath, newIndexPath.section == 0 {
                        tableView.insertRows(at: [transform(newIndexPath)], with: .fade)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath,
                        indexPath.section == 0 && newIndexPath.section == 0 {
                        tableView.reloadRows(at: [transform(indexPath), transform(newIndexPath)], with: .none)
                    }
                case .update:
                    if let indexPath = change.indexPath, indexPath.section == 0 {
                        tableView.reloadRows(at: [transform(indexPath)], with: .none)
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
            if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 1)) as? UploadCell,
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
                .object(atRow: UInt(indexPath.row), inSection: 0, with: self.mappings) as? Upload
        }

        return upload
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: indexPath.section + 1)
    }
}

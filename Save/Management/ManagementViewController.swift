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

    @IBOutlet weak var backBt: UIBarButtonItem? {
        didSet {
            backBt?.title = NSLocalizedString("Back", comment: "")
        }
    }


    private lazy var readConn = Db.newLongLivedReadConn()

    private lazy var mappings = YapDatabaseViewMappings(
        groups: UploadsView.groups, view: UploadsView.name)

    private var count: Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        readConn?.update(mappings: mappings)

        removeDone(async: false)

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

        UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isProximityMonitoringEnabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        removeDone()

        delegate?.done()

        UIApplication.shared.isIdleTimerDisabled = false
        UIDevice.current.isProximityMonitoringEnabled = false
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

    override public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("Remove", comment: ""))
        { [weak self] _, _, completionHandler in
            guard let upload = self?.getUpload(indexPath) else {
                return completionHandler(false)
            }

            upload.remove() {
                completionHandler(true)
            }
        }

        return UISwipeActionsConfiguration(actions: [action])
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        if editing {
            NotificationCenter.default.post(name: .uploadManagerPause, object: nil)
        }
        else {
            NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
        }

        updateTitle()
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

        return getUpload(indexPath)?.state != .downloading
    }

    /**
     Reading all objects and rewriting them seems expensive, but is the best solution
     I could come up with when using YapDatabase.
    */
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        Db.writeConn?.asyncReadWrite { tx in
            var uploads: [Upload] = tx.findAll(group: UploadsView.groups.first, in: UploadsView.name)

            uploads.insert(uploads.remove(at: fromIndexPath.row), at: to.row)

            var i = 0
            for upload in uploads {
                if upload.order != i {
                    upload.order = i
                    tx.replace(upload, forKey: upload.id, inCollection: Upload.collection)
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
        default:
            break
        }
    }

    func showError(_ upload: Upload) {
        UploadErrorAlert.present(self, upload)
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
        var needsUpdate = false

        if let changes = readConn?.getChanges(mappings) {
            if changes.forceFull {
                // No animation. Otherwise this can happen:
                // NSInternalInconsistencyException, reason: 'Cannot animate reordering cell because it already has an animation'
                tableView.reloadSections([1], with: .none)

                needsUpdate = true
            }
            else if !changes.rowChanges.isEmpty {
                tableView.beginUpdates()

                // NOTE: Sections other than 0 are ignored, because `UploadsView`
                // also tracks changes in `Asset`s, so `UploadManager` can update
                // its referenced assets, when their status changes.
                // (Needed, when movie import takes longer as the user hits upload.)

                for change in changes.rowChanges {
                    switch change.type {
                    case .delete:
                        if let indexPath = change.indexPath, indexPath.section == 0 {
                            tableView.deleteRows(at: [transform(indexPath)], with: .fade)
                            needsUpdate = true
                        }

                    case .insert:
                        if let newIndexPath = change.newIndexPath, newIndexPath.section == 0 {
                            tableView.insertRows(at: [transform(newIndexPath)], with: .fade)
                            needsUpdate = true
                        }

                    case .move:
                        if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath,
                            indexPath.section == 0 && newIndexPath.section == 0 
                        {
                            tableView.reloadRows(at: [transform(indexPath), transform(newIndexPath)], with: .none)
                            needsUpdate = true
                        }

                    case .update:
                        if let indexPath = change.indexPath, indexPath.section == 0 {
                            tableView.reloadRows(at: [transform(indexPath)], with: .none)
                            needsUpdate = true
                        }

                    @unknown default:
                        break
                    }
                }

                tableView.endUpdates()
            }
        }

        if needsUpdate {
            updateTitle()
            setButton()
        }
    }


    // MARK: Private Methods

    private func updateTitle() {
        let titleView = navigationItem.titleView as? MultilineTitle ?? MultilineTitle()

        if isEditing {
            titleView.title.text = NSLocalizedString("Edit Media", comment: "")
            titleView.subtitle.text = NSLocalizedString("Uploading is paused", comment: "")

            navigationItem.titleView = titleView

            return
        }

        readConn?.asyncRead { [weak self] tx in
            let left = UploadsView.countUploading(tx)

            DispatchQueue.main.async {
                titleView.title.text = self?.count == 0
                    ? NSLocalizedString("Done", comment: "")
                    : (left > 0
                       ? NSLocalizedString("Uploading…", comment: "")
                       : NSLocalizedString("Waiting…", comment: ""))
                titleView.subtitle.text = String.localizedStringWithFormat(NSLocalizedString("%u left", comment: "#bc-ignore!"), left)

                self?.navigationItem.titleView = titleView
            }
        }
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
        readConn?.object(at: IndexPath(row: indexPath.row, section: 0), in: mappings)
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        IndexPath(row: indexPath.row, section: indexPath.section + 1)
    }

    /*
     Will delete the done uploads.
     */
    private func removeDone(async: Bool = true) {
        let block = { (tx: YapDatabaseReadWriteTransaction) in

            let uploads: [Upload] = tx.findAll { upload in
                upload.preheat(tx, deep: false)

                // Remove all which are uploaded, which don't have an
                // asset anymore, or where the asset says, it's uploaded.
                // (That happens, when the app gets killed.)
                return upload.state == .downloaded || upload.asset?.isUploaded ?? true
            }

            tx.removeObjects(forKeys: uploads.map({ $0.id }), inCollection: Upload.collection)
        }

        if async {
            Db.writeConn?.asyncReadWrite(block)
        }
        else {
            Db.writeConn?.readWrite(block)
        }
    }
}

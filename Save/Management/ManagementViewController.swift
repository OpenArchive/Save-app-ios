//
//  ManagementViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class ManagementViewController: BaseTableViewController, UploadCellDelegate {

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
        
        return true
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }

        switch getUpload(indexPath)?.state {
        case .pending, .paused:
            return true

        default:
            return false
        }
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
                    tx.replace(upload)
                }

                i += 1
            }
        }
    }


    // MARK: UploadCellDelegate

    func progressTapped(_ upload: Upload, _ button: ProgressButton) {
        switch button.state {
        case .paused:
            NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
        case .pending, .uploading:
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
        // DO NOT ANIMATE. Crash could occur:
        // uncaught exception 'NSInternalInconsistencyException',
        // reason: 'Cannot animate inserted cell because it already has an animation

        // ALSO: Don't try to use detailed delete/insert/move/update support.
        // It will also only lead to the same crashes when the user tries to reorder things.
        // Probably a race condition with the reorder animation triggered by the user drag?

        // ALSO: Only reload the full table. Trying to only reload a section will only
        // lead to NSInternalInconsistencyExceptions, eventually, too.

        if readConn?.hasChanges(mappings) ?? false {
            tableView.reloadData()

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
                    : (left > 0 && !UploadManager.shared.waiting
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
                return upload.state == .uploaded || upload.asset?.isUploaded ?? true
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

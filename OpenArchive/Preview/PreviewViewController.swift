//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class PreviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PreviewCellDelegate, DoneDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolbar: UIToolbar!

    private let sc = SelectedCollection()

    /**
     Remove action for table list row. Deletes an asset.
     */
    private lazy var removeAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Remove".localize())
        { (action, indexPath) in
            if let asset = self.sc.getAsset(indexPath) {
                self.present(RemoveAssetAlert([asset]), animated: true)
            }

            self.tableView.setEditing(false, animated: true)
        }

        return action
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = "Preview".localize()
        navigationItem.titleView = title

        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        updateTitle()

        tableView.reloadData()
    }


    // MARK: UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sc.sections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sc.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PreviewCell.reuseId, for: indexPath) as! PreviewCell
        cell.asset = sc.getAsset(indexPath)
        cell.delegate = self

        return cell
    }


    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PreviewCell.height
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // If the currently selected number of rows is exactly one, that means,
        // that there was no selection before, and this item was just selected.
        // In that case, ignore the selection and instead move to DarkroomViewController.
        // Because in this scenario, the first selection is done by a long press,
        // which basically enters an "edit" mode. (See #longPressItem.)
        if tableView.indexPathsForSelectedRows?.count ?? 0 != 1 {

            // For an unkown reason, this isn't done automatically.
            tableView.cellForRow(at: indexPath)?.isSelected = true

            return
        }

        tableView.deselectRow(at: indexPath, animated: false)

        performSegue(withIdentifier: MainViewController.segueShowDarkroom, sender: (indexPath.row, nil as DarkroomViewController.DirectEdit?))
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        // For an unkown reason, this isn't done automatically.
        tableView.cellForRow(at: indexPath)?.isSelected = false

        if tableView.indexPathsForSelectedRows?.count ?? 0 == 0 {
            toggleToolbar(false)
        }
    }

    public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [removeAction]
    }


    // MARK: PreviewCellDelegate

    func edit(_ asset: Asset, _ directEdit: DarkroomViewController.DirectEdit? = nil) {
        if let indexPath = sc.getIndexPath(asset) {
            performSegue(withIdentifier: MainViewController.segueShowDarkroom, sender: (indexPath.row, directEdit))
        }
    }


    // MARK: DoneDelegate

    func done() {
        navigationController?.popViewController(animated: true)
    }


    // MARK: Navigation

     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DarkroomViewController {
            if let (index, directEdit) = sender as? (Int, DarkroomViewController.DirectEdit?) {
                vc.selected = index
                vc.directEdit = directEdit
                vc.addMode = true
            }
        }
        else if let vc = segue.destination as? BatchEditViewController {
            vc.assets = sender as? [Asset]
        }
        else if let vc = segue.destination as? ManagementViewController {
            vc.delegate = self
        }
     }


    // MARK: Actions

    @IBAction func upload() {
        Db.writeConn?.asyncReadWrite { transaction in
            var order = 0

            transaction.enumerateKeysAndObjects(inCollection: Upload.collection) { key, object, stop in
                if let upload = object as? Upload, upload.order >= order {
                    order = upload.order + 1
                }
            }

            guard let group = self.sc.group else {
                return
            }

            if let id = self.sc.id,
                let collection = transaction.object(forKey: id, inCollection: Collection.collection) as? Collection {

                collection.close()

                transaction.setObject(collection, forKey: collection.id,
                                      inCollection: Collection.collection)
            }

            (transaction.ext(AbcFilteredByCollectionView.name) as? YapDatabaseViewTransaction)?
                .enumerateKeysAndObjects(inGroup: group) { collection, key, object, index, stop in

                    if let asset = object as? Asset {
                        let upload = Upload(order: order, asset: asset)
                        transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                        order += 1
                    }
            }
        }

        navigationController?.popViewController(animated: true)
    }

    @IBAction func longPressCell(_ sender: UILongPressGestureRecognizer) {

        // We only recognize this the first time, it is triggered.
        // It will continue triggering with .changed and .ended states, but
        // .ended is only released after the user lifts the finger which feels
        // awkward.
        if sender.state != .began {
            return
        }

        if let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView)) {
            tableView.cellForRow(at: indexPath)?.isSelected = true
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)

            toggleToolbar(true)
        }
    }

    @IBAction func editAssets() {
        let assets = getSelectedAssets()

        if assets.count == 1 {
            if let indexPath = tableView.indexPathsForSelectedRows?[0] {
                // Trigger deselection, so edit mode UI goes away.
                tableView.deselectRow(at: indexPath, animated: false)
                tableView(tableView, didDeselectRowAt: indexPath)

                // Trigger selection, so DarkroomViewController gets pushed.
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
                tableView(tableView, didSelectRowAt: indexPath)
            }
        }
        else if assets.count > 1 {
            performSegue(withIdentifier: MainViewController.segueShowBatchEdit, sender: assets)
        }
    }

    @IBAction func removeAssets() {
        present(RemoveAssetAlert(getSelectedAssets(), { self.toggleToolbar(false) }), animated: true)
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let (sectionChanges, rowChanges) = sc.yapDatabaseModified()

        updateTitle()

        if sectionChanges.count < 1 && rowChanges.count < 1 {
            return
        }

        tableView.beginUpdates()

        for change in sectionChanges {
            switch change.type {
            case .delete:
                tableView.deleteSections(IndexSet(integer: Int(change.index)), with: .fade)

            case .insert:
                tableView.insertSections(IndexSet(integer: Int(change.index)), with: .fade)

            default:
                break
            }
        }

        for change in rowChanges {
            switch change.type {
            case .delete:
                if let indexPath = change.indexPath {
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            case .insert:
                if let newIndexPath = change.newIndexPath {
                    tableView.insertRows(at: [newIndexPath], with: .fade)
                }
            case .move:
                if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                    tableView.moveRow(at: indexPath, to: newIndexPath)
                }
            case .update:
                if let indexPath = change.indexPath {
                    tableView.reloadRows(at: [indexPath], with: .none)
                }
            @unknown default:
                break
            }
        }

        tableView.endUpdates()

        if sc.count < 1 {
            // When we don't have any assets anymore after an update, because the
            // user deleted them, it doesn't make sense, to show this view
            // controller anymore. So we leave here.
            navigationController?.popViewController(animated: true)
        }
    }


    // MARK: Private Methods

    private func updateTitle() {
        let projectName = sc.collection?.project.name
        (navigationItem.titleView as? MultilineTitle)?.subtitle.text = projectName == nil ? nil : "Upload to %".localize(value: projectName!)
    }

    /**
     Shows/hides the toolbar, depending on the toggle.

     - parameter toggle: true, to show toolbar, false to hide.
     */
    private func toggleToolbar(_ toggle: Bool) {
        toolbar.toggle(toggle, animated: true)
    }

    private func getSelectedAssets() -> [Asset] {
        var assets = [Asset]()

        for indexPath in self.tableView.indexPathsForSelectedRows ?? [] {
            if let asset = sc.getAsset(indexPath) {
                assets.append(asset)
            }
        }

        return assets
    }
}

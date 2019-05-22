//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class PreviewViewController: UITableViewController, PreviewCellDelegate, DoneDelegate {

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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sc.sections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sc.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PreviewCell.reuseId, for: indexPath) as! PreviewCell
        cell.asset = sc.getAsset(indexPath)
        cell.delegate = self

        return cell
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PreviewCell.height
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showDarkroomSegue", sender: (indexPath.row, nil as DarkroomViewController.DirectEdit?))
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [removeAction]
    }


    // MARK: PreviewCellDelegate

    func edit(_ asset: Asset, _ directEdit: DarkroomViewController.DirectEdit? = nil) {
        if let indexPath = sc.getIndexPath(asset) {
            performSegue(withIdentifier: "showDarkroomSegue", sender: (indexPath.row, directEdit))
        }
    }


    // MARK: DoneDelegate

    func done() {
        navigationController?.popViewController(animated: true)
    }


    // MARK: Navigation

     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editVc = segue.destination as? DarkroomViewController {
            if let (index, directEdit) = sender as? (Int, DarkroomViewController.DirectEdit?) {
                editVc.selected = index
                editVc.directEdit = directEdit
                editVc.addMode = true
            }
        }
        else if let mvc = segue.destination as? ManagementViewController {
            mvc.delegate = self
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
}

//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class PreviewViewController: UITableViewController, PreviewCellDelegate, DoneDelegate {

    var collection: Collection!

    /**
     Delete action for table list row. Deletes an asset.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let title = "Delete Asset".localize()
            let asset = self.collection.assets[indexPath.row]
            let message = "Are you sure you want to delete \"%\"?".localize(value: asset.filename)
            let handler: AlertHelper.ActionHandler = { _ in
                Db.writeConn?.asyncReadWrite() { transaction in
                    transaction.removeObject(forKey: asset.id, inCollection: Asset.collection)
                }

                self.collection.assets.remove(at: indexPath.row)

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.tableView.endUpdates()

                // Leave, if no assets anymore.
                if self.collection.assets.count < 1 {
                    self.navigationController?.popViewController(animated: true)
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
        title.title.text = "Preview".localize()

        if let projectName = collection.project.name {
            title.subtitle.text = "Upload to %".localize(value: projectName)
        }

        navigationItem.titleView = title

        tableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        tableView.reloadData()
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return collection.assets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PreviewCell.reuseId, for: indexPath) as! PreviewCell

        cell.asset = collection.assets[indexPath.row]
        cell.delegate = self

        return cell
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PreviewCell.height
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        edit(collection.assets[indexPath.row])
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }

    // MARK: PreviewCellDelegate

    func edit(_ asset: Asset, _ directEdit: EditViewController.DirectEdit? = nil) {
        let index = collection.assets.firstIndex(of: asset)

        performSegue(withIdentifier: "showEditSegue", sender: (index, directEdit))
    }


    // MARK: DoneDelegate

    func done() {
        navigationController?.popViewController(animated: true)
    }


    // MARK: Navigation

     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editVc = segue.destination as? EditViewController {
            editVc.collection = collection

            if let (index, directEdit) = sender as? (Int, EditViewController.DirectEdit?) {
                editVc.selected = index
                editVc.directEdit = directEdit
            }
        }
        else if let mvc = segue.destination as? ManagementViewController {
            mvc.delegate = self
        }
     }


    // MARK: Actions

    @IBAction func upload() {
        collection.close()

        var uploads = [Upload]()

        for asset in collection.assets {
            uploads.append(Upload(asset: asset))
        }

        Db.writeConn?.asyncReadWrite { transaction in
            var i = 0

            transaction.enumerateKeys(inCollection: Upload.collection) { key, stop in
                if let k = Int(key), k > i {
                    i = k
                }
            }

            for upload in uploads {
                transaction.setObject(upload, forKey: String(i), inCollection: Upload.collection)
                i += 1
            }
        }

        performSegue(withIdentifier: "showManagmentSegue", sender: nil)
    }
}

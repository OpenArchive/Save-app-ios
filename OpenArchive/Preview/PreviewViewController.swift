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
     Remove action for table list row. Deletes an asset.
     */
    private lazy var removeAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Remove".localize())
        { (action, indexPath) in
            let asset = self.collection.assets[indexPath.row]

            self.present(RemoveAssetAlert(asset, {
                self.collection.assets.remove(at: indexPath.row)

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.tableView.endUpdates()

                // Leave, if no assets anymore.
                if self.collection.assets.count < 1 {
                    self.done()
                }
            }), animated: true)

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
        return [removeAction]
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

        Db.writeConn?.asyncReadWrite { transaction in
            var order = 0

            transaction.setObject(self.collection, forKey: self.collection.id,
                                  inCollection: Collection.collection)

            transaction.enumerateKeysAndObjects(inCollection: Upload.collection) { key, object, stop in
                if let upload = object as? Upload, upload.order >= order {
                    order = upload.order + 1
                }
            }

            for asset in self.collection.assets {
                let upload = Upload(order: order, asset: asset)
                transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                order += 1
            }
        }

        performSegue(withIdentifier: "showManagmentSegue", sender: nil)
    }
}

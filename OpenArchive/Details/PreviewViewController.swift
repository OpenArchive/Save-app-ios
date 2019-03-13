//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class PreviewViewController: UITableViewController, PreviewCellDelegate {

    var collection: Collection!

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

    // MARK: - Table view data source

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

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PreviewCell.height
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        edit(collection.assets[indexPath.row])
    }


    // MARK: PreviewCellDelegate

    func edit(_ asset: Asset, _ directEdit: EditViewController.DirectEdit? = nil) {
        let index = collection.assets.firstIndex(of: asset)

        performSegue(withIdentifier: "showEditSegue", sender: (index, directEdit))
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

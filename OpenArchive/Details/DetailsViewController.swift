//
//  DetailsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class DetailsViewController: UITableViewController, PreviewCellDelegate {

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
//        let asset = collection.assets[indexPath.row]

        print("[\(String(describing: type(of: self)))]#didSelectRowAt")
    }


    // MARK: PreviewCellDelegate

    func editPeople(_ asset: Asset) {
        print("[\(String(describing: type(of: self)))]#editPeople")
    }

    func editLocation(_ asset: Asset) {
        print("[\(String(describing: type(of: self)))]#editLocation")
    }
}

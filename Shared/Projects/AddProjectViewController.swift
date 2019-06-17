//
//  AddProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.06.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class AddProjectViewController: BaseTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        tableView.register(TitleCell.nib, forCellReuseIdentifier: TitleCell.reuseId)
        tableView.register(BigMenuItemCell.nib, forCellReuseIdentifier: BigMenuItemCell.reuseId)
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: TitleCell.reuseId, for: indexPath) as? TitleCell {

            return cell.set("Add a Project".localize(), "Set up where you want your media to be stored.".localize())
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: BigMenuItemCell.reuseId, for: indexPath) as! BigMenuItemCell

        if indexPath.row == 1 {
            cell.label?.text = "Create New Project".localize()
            cell.detailedDescription?.text = "Add a project folder to the server that anyone can upload to.".localize()
        }
        else {
            cell.label?.text = "Browse Existing Projects".localize()
            cell.detailedDescription?.text = "Choose a project folder from the server.".localize()
        }

        return cell
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? TitleCell.fullHeight : BigMenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc: UIViewController

        if indexPath.row == 1 {
            vc = NewProjectViewController()
        }
        else {
            vc = BrowseViewController()
        }

        navigationController?.pushViewController(vc, animated: true)
    }

    
    // MARK: Actions

    @objc func cancel() {
        dismiss(animated: true)
    }
}

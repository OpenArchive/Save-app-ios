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

        // We cannot browse the Internet Archive, so show NewProjectViewController
        // immediately instead of this scene.
        if SelectedSpace.space is IaSpace,
            var stack = navigationController?.viewControllers {

            stack.removeAll { $0 is AddProjectViewController }
            stack.append(NewProjectViewController())
            navigationController?.setViewControllers(stack, animated: false)
        }
        else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }

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

            return cell.set(NSLocalizedString("Add a Project", comment: ""),
                            NSLocalizedString("Set up where you want your media to be stored.", comment: ""))
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: BigMenuItemCell.reuseId, for: indexPath) as! BigMenuItemCell

        if indexPath.row == 1 {
            cell.accessibilityIdentifier = "cellCreateNewProject"
            cell.label?.text = NSLocalizedString("Create New Project", comment: "")
            cell.detailedDescription?.text = NSLocalizedString("Add a project folder to the server that anyone can upload to.", comment: "")
        }
        else {
            cell.label?.text = NSLocalizedString("Browse Existing Projects", comment: "")
            cell.detailedDescription?.text = NSLocalizedString("Choose a project folder from the server.", comment: "")
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
}

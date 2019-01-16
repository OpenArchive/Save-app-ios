//
//  MyAccountViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MyAccountViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TableHeader.self, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)
        tableView.register(ProfileCell.nib, forCellReuseIdentifier: ProfileCell.reuseId)
        tableView.register(MenuItemCell.nib, forCellReuseIdentifier: MenuItemCell.reuseId)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)

        tableView.reloadData()
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        case 2:
            return 1
        case 3:
            return 3
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return ProfileCell.height
        }

        return MenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.reuseId, for: indexPath) as? ProfileCell {

            return cell.set()
        }

        if let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as? MenuItemCell {
            switch indexPath.section {
            case 1:
                switch indexPath.row {
                case 0:
                    cell.set(NSLocalizedString("Private Server", comment: ""), isPlaceholder: true)
                case 1:
                    cell.set(NSLocalizedString("Internet Archive", comment: ""), isPlaceholder: true)
                default:
                    cell.set("")
                }
            case 2:
                switch indexPath.row {
                case 0:
                    cell.set(NSLocalizedString("Create New Project", comment: ""), isPlaceholder: true)
                default:
                    cell.set("")
                }
            case 3:
                cell.addIndicator.isHidden = true
                switch indexPath.row {
                case 0:
                    cell.set(NSLocalizedString("Data Use", comment: ""))
                case 1:
                    cell.set(NSLocalizedString("Privacy", comment: ""))
                default:
                    cell.set(NSLocalizedString("About", comment: ""))
                }
            default:
                cell.set("")
            }

            return cell
        }


        return UITableViewCell()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId) as? TableHeader {
            let heightZero = header.heightAnchor.constraint(equalToConstant: 0)

            heightZero.isActive = false

            switch section {
            case 1:
                header.text = NSLocalizedString("Spaces", comment: "")
            case 2:
                header.text = NSLocalizedString("Projects", comment: "")
            case 3:
                header.text = NSLocalizedString("Settings", comment: "")
            default:
                heightZero.isActive = true
            }

            return header
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            performSegue(withIdentifier: "showEditProfileSegue", sender: nil)
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

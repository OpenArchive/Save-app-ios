//
//  FormViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

/**
 Own base class of Eureka's FormViewController which adds our own base style:

 - UITableView.Style.plain instead of .grouped
 - White background
 - No trailing empty cells
 - Own special header
 */
class FormViewController: Eureka.FormViewController {

    init() {
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TableHeader.self, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)

        tableView?.backgroundColor = UIColor.white
        tableView.tableFooterView = UIView()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId)
    }
}

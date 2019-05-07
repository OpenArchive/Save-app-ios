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

    var delegate: DoneDelegate?

    lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()

    init() {
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TableHeader.nib, forHeaderFooterViewReuseIdentifier: TableHeader.reuseId)

        tableView?.backgroundColor = UIColor.white
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        view.tintColor = UIColor.accent
        NavigationAccessoryView.appearance().tintColor = UIColor.accent
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> TableHeader? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: TableHeader.reuseId) as? TableHeader
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }
}

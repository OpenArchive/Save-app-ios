//
//  NewProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class NewProjectViewController: BaseProjectViewController, BrowseDelegate {

    private var isModal = false

    init(isModal: Bool = false) {
        super.init(Project(space: SelectedSpace.space))

        self.isModal = isModal
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        navigationItem.title = "New Project".localize()


        if isModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(connect))

        form
            +++ LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.textAlignment = .center
                $0.title = "Curate your own project or browse for an existing one.".localize()
            }

            +++ nameRow.cellUpdate { cell, _ in
                self.enableDone()
            }

        if !(project.space is IaSpace) {
            form
            +++ ButtonRow() {
                $0.title = "Browse Projects".localize()
            }
            .onCellSelection { cell, row in
                let browseVc = BrowseViewController()
                browseVc.delegate = self

                self.navigationController?.pushViewController(browseVc, animated: true)
            }
        }

        super.viewDidLoad()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }


    // MARK: BrowseDelegate

    func didSelect(name: String) {
        nameRow.value = name
        nameRow.disabled = true
        nameRow.evaluateDisabled()
    }


    // MARK: Actions

    @objc override func connect() {
        super.connect()

        if isModal {
            cancel()
        }
    }

    @objc func cancel() {
        dismiss(animated: true)
    }
}

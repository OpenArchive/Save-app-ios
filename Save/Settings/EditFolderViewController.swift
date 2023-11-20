//
//  EditFolderViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 29.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class EditFolderViewController: BaseFolderViewController {

    private var archiveLabel: String {
        return project.active ? NSLocalizedString("Archive Folder", comment: "") : NSLocalizedString("Unarchive Folder", comment: "")
    }

    /**
     Store, as long as this is set to true.
     Workaround for issue #122: Project gets deleted, but re-added when scene is
     left, due to various #store calls which get triggered.
    */
    private var doStore = true

    private lazy var ccEnabled = SelectedSpace.space?.license == nil

    private lazy var cc = CcSelector(individual: ccEnabled)

    override func viewDidLoad() {
        navigationItem.title = project.name

        nameRow.value = project.name

        cc.set(project.license, enabled: ccEnabled && project.active)

        form
        +++ nameRow.cellUpdate { cell, row in
            cell.textField.textAlignment = .left

            if row.isValid {
                self.project.name = row.value
                self.navigationItem.title = self.project.name

                if self.doStore {
                    self.store()
                }
            }
        }

        +++ Section("")

        <<< cc.ccSw.onChange(ccLicenseChanged)

        <<< cc.remixSw.onChange(ccLicenseChanged)

        <<< cc.shareAlikeSw.onChange(ccLicenseChanged)

        <<< cc.commercialSw.onChange(ccLicenseChanged)

        <<< cc.licenseRow

        <<< cc.learnMoreRow

        +++ ButtonRow() {
            $0.title = NSLocalizedString("Remove from App", comment: "")
            $0.cell.tintColor = .systemRed
        }
        .onCellSelection { [weak self] cell, row in
            self?.present(RemoveProjectAlert(self!.project, { success in
                guard success else {
                    return
                }

                self?.doStore = false
                self?.navigationController?.popViewController(animated: true)
            }),
                         animated: true)
        }

        <<< ButtonRow() {
            $0.title = self.archiveLabel
        }
        .onCellSelection { [weak self] cell, row in
            self?.project.active = !(self?.project.active ?? false)

            // When unarchiving and a space license is available, always use that,
            // to avoid inconsistent licensing settings.
            if self?.project.active ?? false, let license = SelectedSpace.space?.license {
                self?.project.license = license
            }

            if self?.doStore ?? false {
                self?.store()
            }

            cell.textLabel?.text = self?.archiveLabel
        }

        super.viewDidLoad()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // The second one has a title.
        return section == 1 ? TableHeader.height : TableHeader.reducedHeight
    }


    // MARK: Private Methods

    private func ccLicenseChanged(_ row: SwitchRow) {
        project.license = cc.get()

        if doStore {
            store()
        }
    }
}

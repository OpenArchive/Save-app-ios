//
//  EditProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 29.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class EditProjectViewController: BaseProjectViewController {

    static let ccDomain = "creativecommons.org"
    static let ccUrl = "https://%@/licenses/%@/4.0/"

    private let ccSw = SwitchRow("cc") {
        $0.title = "Allow Creative Commons use for all media in this project".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = UIColor.accent
    }

    private let remixSw = SwitchRow("remixSw") {
        $0.title = "Allow anyone to remix and share".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = UIColor.accent
        $0.hidden = "$cc != true"
    }

    private let shareAlikeSw = SwitchRow() {
        $0.title = "Require them to share like you have".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = UIColor.accent
        $0.disabled = "$remixSw != true"
        $0.hidden = "$cc != true"
    }

    private let commercialSw = SwitchRow() {
        $0.title = "Allow commercial use".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = UIColor.accent
        $0.hidden = "$cc != true"
    }

    private let licenseRow = LabelRow() {
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.hidden = "$cc != true"
    }


    private var archiveLabel: String {
        return project.active ? "Archive Project".localize() : "Unarchive Project".localize()
    }

    /**
     Store, as long as this is set to true.
     Workaround for issue #122: Project gets deleted, but re-added when scene is
     left, due to various #store calls which get triggered.
    */
    private var doStore = true

    override func viewDidLoad() {
        navigationItem.title = project.name

        nameRow.value = project.name

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

            +++ Section("Creative Commons".localize().localizedUppercase)

            <<< ccSw.onChange(ccLicenseChanged)

            <<< remixSw.onChange(ccLicenseChanged)

            <<< shareAlikeSw.onChange(ccLicenseChanged)

            <<< commercialSw.onChange(ccLicenseChanged)

            <<< licenseRow.onCellSelection { cell, row in
                if let license = row.title,
                    let url = URL(string: license) {
                    UIApplication.shared.open(url)
                }
            }

            +++ ButtonRow() {
                $0.title = "Remove from App".localize()
                $0.cell.tintColor = UIColor.red
            }
            .onCellSelection { cell, row in
                self.present(RemoveProjectAlert(self.project, {
                    self.doStore = false
                    self.navigationController?.popViewController(animated: true)
                }),
                             animated: true)
            }

            <<< ButtonRow() {
                $0.title = self.archiveLabel
            }
            .onCellSelection { cell, row in
                self.project.active = !self.project.active

                if self.doStore {
                    self.store()
                }

                cell.textLabel?.text = self.archiveLabel
            }

        if let license = project.license,
            license.localizedCaseInsensitiveContains(EditProjectViewController.ccDomain) {

            ccSw.value = true
            remixSw.value = !license.localizedCaseInsensitiveContains("-nd")
            shareAlikeSw.value = !shareAlikeSw.isDisabled && license.localizedCaseInsensitiveContains("-sa")
            commercialSw.value = !license.localizedCaseInsensitiveContains("-nc")
            licenseRow.title = license
        }
        else {
            ccSw.value = false
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
        if ccSw.value ?? false {
            var license = "by"

            if remixSw.value ?? false {
                if !(commercialSw.value ?? false) {
                    license += "-nc"
                }

                if shareAlikeSw.value ?? false {
                    license += "-sa"
                }
            } else {
                shareAlikeSw.value = false

                if !(commercialSw.value ?? false) {
                    license += "-nc"
                }

                license += "-nd"
            }

            project.license = String(format: EditProjectViewController.ccUrl,
                                     EditProjectViewController.ccDomain,
                                     license)
        } else {
            project.license = nil
        }

        licenseRow.title = project.license
        licenseRow.updateCell()

        if doStore {
            store()
        }
    }
}

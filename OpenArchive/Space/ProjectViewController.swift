//
//  ProjectViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class ProjectViewController: FormViewController, BrowseDelegate {

    private var project: Project
    private var isNew = false

    private let nameRow = TextRow() {
        $0.title = "Name".localize()
        $0.add(rule: RuleRequired())
    }

    private let ccSw = SwitchRow("cc") {
        $0.title = "Creative Commons License".localize()
        $0.cell.textLabel?.numberOfLines = 0
    }

    private let remixSw = SwitchRow("remixSw") {
        $0.title = "Allow anyone to remix and share media in this project?".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.hidden = "$cc != true"
    }

    private let shareAlikeSw = SwitchRow() {
        $0.title = "Require them to share like you have?".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.disabled = "$remixSw != true"
        $0.hidden = "$cc != true"
    }

    private let commercialSw = SwitchRow() {
        $0.title = "Allow commercial use?".localize()
        $0.cell.textLabel?.numberOfLines = 0
        $0.hidden = "$cc != true"
    }

    private let licenseRow = LabelRow() {
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.hidden = "$cc != true"
    }


    private var archiveLabel: String {
        return project.active ? "Archive Project".localize() : "Unarchive Project".localize()
    }

    init(_ project: Project? = nil) {
        if project != nil {
            self.project = project!
        }
        else {
            self.project = Project(space: SelectedSpace.space)
            isNew = true
        }

        super.init()
    }

    required init?(coder decoder: NSCoder) {
        project = decoder.decodeObject() as! Project

        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if isNew {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done, target: self, action: #selector(connect))
        }
        else {
            navigationItem.title = project.name
        }

        nameRow.value = project.name

        if isNew {
            form

            +++ LabelRow() {
                $0.title = "New Project".localize()
            }
            .cellUpdate { cell, row in

                // TODO: This is not centered, yet, despite trying so hard.
                cell.textLabel?.textAlignment = .center
                cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 30)
                cell.textLabel?.textColor = UIColor.accent

                if let superview = cell.superview {
                    cell.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
                    cell.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
                    cell.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
                    cell.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
                }
            }

            <<< LabelRow() {
                $0.cell.textLabel?.numberOfLines = 0
                $0.cell.textLabel?.textAlignment = .center
                $0.title = "Curate your own project or browse for an existing one.".localize()
            }
        }

        form
            +++ nameRow.cellUpdate() { _, row in
                if self.isNew {
                    self.enableDone()
                }
                else {
                    self.project.name = row.value
                    self.navigationItem.title = self.project.name
                    self.store()
                }
            }

        if !isNew {
            form

            +++ ccSw.onChange(ccLicenseChanged)

            <<< remixSw.onChange(ccLicenseChanged)

            <<< shareAlikeSw.onChange(ccLicenseChanged)

            <<< commercialSw.onChange(ccLicenseChanged)

            <<< licenseRow.onCellSelection { cell, row in
                if let license = row.title,
                    let url = URL(string: license) {
                    UIApplication.shared.open(url)
                }
            }
        }

        if isNew {
            form

            +++ ButtonRow() {
                $0.title = "Browse Projects".localize()
            }
            .onCellSelection { cell, row in
                if let browseVc = BrowseViewController.instantiate() {
                    browseVc.delegate = self

                    self.navigationController?.pushViewController(browseVc, animated: true)
                }
            }
        }
        else {
            form

            +++ ButtonRow() {
                $0.title = "Delete Project".localize()
                $0.cell.tintColor = UIColor.red
            }
            .onCellSelection { cell, row in
                self.present(DeleteProjectAlert(self.project,
                                                { self.navigationController?.popViewController(animated: true) }),
                             animated: true)
            }

            <<< ButtonRow() {
                $0.title = self.archiveLabel
            }
            .onCellSelection { cell, row in
                self.project.active = !self.project.active

                self.store()

                cell.textLabel?.text = self.archiveLabel
            }
        }

        if let license = project.license,
            license.localizedCaseInsensitiveContains(BaseDetailsViewController.ccDomain) {

            ccSw.value = true
            remixSw.value = !license.localizedCaseInsensitiveContains("-nd")
            shareAlikeSw.value = !shareAlikeSw.isDisabled && license.localizedCaseInsensitiveContains("-sa")
            commercialSw.value = !license.localizedCaseInsensitiveContains("-nc")
            licenseRow.title = license
        }
        else {
            ccSw.value = false
        }

        form.validate()
        enableDone()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }


    // MARK: BrowseDelegate

    func didSelect(name: String) {
        nameRow.value = name
        nameRow.disabled = true
        nameRow.evaluateDisabled()
    }


    // MARK: Actions

    @objc func connect() {
        project.name = nameRow.value

        store()

        // Only animate, if we don't have a delegate: Too much pop animations
        // will end in the last view controller not being popped and it's also
        // too much going on in the UI.
        navigationController?.popViewController(animated: delegate == nil)

        // Could be PrivateServerViewController or InternetArchiveViewController
        // in the onboarding flow / create space flow to ensure a space and
        // project exits.
        delegate?.done()
    }


    // MARK: Private Methods

    private func enableDone() {
        navigationItem.rightBarButtonItem?.isEnabled = nameRow.isValid
    }

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

            project.license = String(format: BaseDetailsViewController.ccUrl,
                                     BaseDetailsViewController.ccDomain,
                                     license)
        } else {
            project.license = nil
        }

        licenseRow.title = project.license
        licenseRow.updateCell()

        store()
    }

    private func store() {
        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(self.project, forKey: self.project.id,
                                  inCollection: Project.collection)
        }
    }
}

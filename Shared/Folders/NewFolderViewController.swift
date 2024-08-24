//
//  Created by Benjamin Erhart on 29.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class NewFolderViewController: BaseFolderViewController {

    private lazy var ccEnabled = SelectedSpace.space?.license == nil

    private lazy var cc = CcSelector(individual: ccEnabled)


    init() {
        super.init(Project(space: SelectedSpace.space))
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    override func viewDidLoad() {
        navigationItem.title = NSLocalizedString("New Folder", comment: "")

        if navigationController?.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel, target: self, action: #selector(dismiss))
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Create", comment: ""), style: .done,
            target: self, action: #selector(connect))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "btDone"

        cc.set(project.license, enabled: ccEnabled && project.active)

        form
        +++ nameRow.cellUpdate { cell, _ in
            self.enableDone()
        }

        +++ Section("")

        <<< cc.ccSw.onChange(ccLicenseChanged)

        <<< cc.remixSw.onChange(ccLicenseChanged)

        <<< cc.shareAlikeSw.onChange(ccLicenseChanged)

        <<< cc.commercialSw.onChange(ccLicenseChanged)

        <<< cc.licenseRow

        <<< cc.learnMoreRow

        super.viewDidLoad()
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return section == 1 ? tableView.separatorView : nil
    }


    // MARK: Private Methods

    private func ccLicenseChanged(_ row: SwitchRow) {
        project.license = cc.get()
    }
}

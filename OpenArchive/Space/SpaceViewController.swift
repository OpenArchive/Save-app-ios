//
//  SpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

class SpaceViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let space = SelectedSpace.space

        navigationItem.title = space?.prettyName

        form
            +++ AvatarRow() {
                $0.disabled = true
                $0.placeholderImage = SelectedSpace.defaultFavIcon
                $0.value = space?.favIcon
            }
            +++ LabelRow() {
                $0.title = "Login Info".localize()
                $0.cell.accessoryType = .disclosureIndicator
            }
            .onCellSelection({ _, _ in
                let vc: UIViewController

                if let space = SelectedSpace.space as? IaSpace {
                    let iavc = InternetArchiveViewController()
                    iavc.space = space
                    vc = iavc
                }
                else if let space = SelectedSpace.space as? WebDavSpace {
                    let psvc = PrivateServerViewController()
                    psvc.space = space
                    vc = psvc
                }
                else {
                    return
                }

                self.navigationController?.pushViewController(vc, animated: true)
            })
            <<< LabelRow() {
                $0.title = "Profile".localize()
                $0.cell.accessoryType = .disclosureIndicator
            }
            .onCellSelection({ _, _ in
                self.navigationController?.pushViewController(EditProfileViewController(), animated: true)
            })
    }
}

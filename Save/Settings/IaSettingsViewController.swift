//
//  IaSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class IaSettingsViewController: BaseViewController {

    @IBOutlet weak var accessKeyLb: UILabel! {
        didSet {
            accessKeyLb.text = NSLocalizedString("Access Key", comment: "")
        }
    }

    @IBOutlet weak var accessKeyTb: TextBox! {
        didSet {
            accessKeyTb.placeholder = NSLocalizedString("Access Key", comment: "")
        }
    }

    @IBOutlet weak var secretKeyLb: UILabel! {
        didSet {
            secretKeyLb.text = NSLocalizedString("Secret Key", comment: "")
        }
    }

    @IBOutlet weak var secretKeyTb: TextBox! {
        didSet {
            secretKeyTb.placeholder = NSLocalizedString("Secret Key", comment: "")
        }
    }

    @IBOutlet weak var removeBt: UIButton! {
        didSet {
            removeBt.setTitle(NSLocalizedString("Remove from App", comment: ""))
        }
    }


    private var space: IaSpace!


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = IaSpace.defaultPrettyName

        navigationController?.setNavigationBarHidden(false, animated: true)


        if let space = SelectedSpace.space as? IaSpace {
            self.space = space
        }
        else {
            return dismiss(nil)
        }

        accessKeyTb.text = space.username
        accessKeyTb.status = .good
        secretKeyTb.text = space.password
        secretKeyTb.status = .good
    }


    @IBAction func remove() {
        guard let space = self.space else {
            return
        }

        AlertHelper.present(
            self, message: NSLocalizedString("This will remove the asset history for that space, too!", comment: ""),
            title: NSLocalizedString("Remove Space", comment: ""),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.destructiveAction(
                    NSLocalizedString("Remove Space", comment: ""),
                    handler: { [weak self] action in
                        Db.writeConn?.asyncReadWrite { tx in
                            tx.remove(space)

                            // Delete selected space, too.
                            SelectedSpace.space = nil
                            SelectedSpace.store(tx)

                            // Find new selected space.
                            tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
                                SelectedSpace.space = space
                                stop = true
                            }

                            // Store newly selected space.
                            SelectedSpace.store(tx)

                            DispatchQueue.main.async {
                                self?.dismiss(nil)
                            }
                        }
                })
            ])
    }
}

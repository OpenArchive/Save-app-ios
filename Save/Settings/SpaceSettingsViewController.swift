//
//  SpaceSettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceSettingsViewController: BaseViewController {


    @IBOutlet weak var removeBt: UIButton! {
        didSet {
            removeBt.setTitle(NSLocalizedString("Remove from App", comment: ""))
        }
    }


    var space: Space?


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    

    @IBAction func remove() {
        guard let id = space?.id else {
            return
        }

        AlertHelper.present(
            self, message: String(format: NSLocalizedString(
                "Removing this server will remove all contained thumbnails from the %@ app.",
                comment: "Placeholder is app name"), Bundle.main.displayName),
            title: NSLocalizedString("Are you sure?", comment: ""),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.destructiveAction(
                    NSLocalizedString("Remove Server", comment: ""),
                    handler: { [weak self] action in
                        Db.writeConn?.asyncReadWrite { tx in
                            tx.removeObject(forKey: id, inCollection: Space.collection)

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
                                self?.afterSpaceRemoved()

                                self?.dismiss(nil)
                            }
                        }
                })
            ])
    }

    func afterSpaceRemoved() {
        // Ignored in default implementation.
    }
}

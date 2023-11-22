//
//  SpaceTypeViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceTypeViewController: UIViewController, WizardDelegatable {

    weak var delegate: WizardDelegate?

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString(
                "To get started, connect to a space to store your media.",
                comment: "")
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString(
                "You can add another storage space and connect to multiple servers.",
                comment: "")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var button = BigButton.create(
            icon: UIImage(systemName: "server.rack"),
            title: NSLocalizedString("Private Server", comment: ""),
            subtitle: NSLocalizedString("Send to a WebDAV server", comment: ""),
            target: self,
            action: #selector(newWebDav),
            container: container,
            above: subtitleLb)

        Db.bgRwConn?.read { tx in
            if tx.find(where: { (_: DropboxSpace) in true }) == nil {
                button = BigButton.create(
                    icon: DropboxSpace.favIcon,
                    title: DropboxSpace.defaultPrettyName,
                    subtitle: String(format: NSLocalizedString("Upload to %@", comment: ""), DropboxSpace.defaultPrettyName),
                    target: self,
                    action: #selector(newDropbox),
                    container: container,
                    above: button,
                    equalHeight: true)
            }

            if tx.find(where: { (_: IaSpace) in true }) == nil {
                button = BigButton.create(
                    icon: IaSpace.favIcon,
                    title: IaSpace.defaultPrettyName,
                    subtitle: String(format: NSLocalizedString("Upload to %@", comment: ""), IaSpace.defaultPrettyName),
                    target: self,
                    action: #selector(newIa),
                    container: container,
                    above: button,
                    equalHeight: true)
            }
        }

        button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16).isActive = true
    }


    // MARK: Actions

    @IBAction func newWebDav() {
        delegate?.next(PrivateServerViewController(), pos: 1)
    }

    @IBAction func newDropbox() {
        delegate?.next(DropboxViewController(), pos: 1)
    }

    @IBAction func newIa() {
        delegate?.next(UIStoryboard.main.instantiate(IaWizardViewController.self), pos: 1)
    }
}

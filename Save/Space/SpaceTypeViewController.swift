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

        let button1 = BigButton.create(
            icon: UIImage(systemName: "server.rack"),
            title: NSLocalizedString("Private Server", comment: ""),
            subtitle: NSLocalizedString("Send to a WebDAV server", comment: ""),
            target: self,
            action: #selector(newWebDav),
            container: view,
            above: subtitleLb)

        Db.bgRwConn?.read { tx in
            var button2: UIView?

            if tx.find(where: { (_: DropboxSpace) in true }) == nil {
                button2 = BigButton.create(
                    icon: DropboxSpace.favIcon,
                    title: DropboxSpace.defaultPrettyName,
                    subtitle: String(format: NSLocalizedString("Upload to %@", comment: ""), DropboxSpace.defaultPrettyName),
                    target: self,
                    action: #selector(newDropbox),
                    container: view,
                    above: button1,
                    equalHeight: true)
            }

            if tx.find(where: { (_: IaSpace) in true }) == nil {
                BigButton.create(
                    icon: IaSpace.favIcon,
                    title: IaSpace.defaultPrettyName,
                    subtitle: String(format: NSLocalizedString("Upload to %@", comment: ""), IaSpace.defaultPrettyName),
                    target: self,
                    action: #selector(newIa),
                    container: view,
                    above: button2 ?? button1,
                    equalHeight: true)
            }
        }
    }


    // MARK: Actions

    @IBAction func newWebDav() {
        delegate?.next(PrivateServerViewController())
    }

    @IBAction func newDropbox() {
        delegate?.next(DropboxViewController())
    }

    @IBAction func newIa() {
        delegate?.next(UIStoryboard.main.instantiate(IaWizardViewController.self))
    }
}

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
                "To get started, connect to a server to store your media.",
                comment: "")
        }
    }
    
    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString(
                "In the side menu, you can add another server and connect to multiple servers",
                comment: "")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var button = BigButton.create(
            icon: UIImage(systemName: "server.rack"),
            title: WebDavSpace.defaultPrettyName,
            subtitle: NSLocalizedString("Send to a WebDAV server", comment: ""),
            target: self,
            action: #selector(newWebDav),
            container: container,
            above: subtitleLb)
        button.accessibilityIdentifier = "viewPrivateServer"
        
        Db.bgRwConn?.read { tx in
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
            //
            //            if tx.find(where: { (_: GdriveSpace) in true }) == nil {
            //                button = BigButton.create(
            //                    icon: GdriveSpace.favIcon,
            //                    title: "\(GdriveSpace.defaultPrettyName)™", // First time should show a "tm". See https://developers.google.com/drive/api/guides/branding
            //                    subtitle: String(format: NSLocalizedString("Upload to %@", comment: ""), GdriveSpace.defaultPrettyName),
            //                    target: self,
            //                    action: #selector(newGdrive),
            //                    container: container,
            //                    above: button,
            //                    equalHeight: true)
            //            }
        }
        
        button.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16).isActive = true
    }
    
    
    // MARK: Actions
    
    @IBAction func newWebDav() {
        delegate?.next(UIStoryboard.main.instantiate(WebDavWizardViewController.self), pos: 1)
    }
    
    @IBAction func newIa() {
        delegate?.next(UIStoryboard.main.instantiate(IaWizardViewController.self), pos: 1)
    }
    
    @IBAction func newGdrive() {
        delegate?.next(UIStoryboard.main.instantiate(GdriveWizardViewController.self), pos: 1)
    }
}

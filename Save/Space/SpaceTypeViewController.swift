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
    
    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString(
                "To get started, connect to a server to store your media.",
                comment: "")
            titleLb.font = .montserrat(forTextStyle: .headline ,with: .traitUIOptimized)
        }
    }
    
    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString(
                "You can add multiple private servers and  one IA at any time.",
                comment: "")
            subtitleLb.font = .montserrat(forTextStyle: .caption2)
            subtitleLb.textColor = .subtitleText
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Select a Server", comment: "")
        var button = BigButton.create(
            icon: UIImage(named: "private_server_teal"),
            title: WebDavSpace.defaultPrettyName,
            subtitle: NSLocalizedString("Connect to a secure \nWebDAV server", comment: ""),
            target: self,
            action: #selector(newWebDav),
            container: container,
            above: emptyView)
        button.accessibilityIdentifier = "viewPrivateServer"
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
        
        Db.bgRwConn?.read { tx in
            if tx.find(where: { (_: IaSpace) in true }) == nil {
                button = BigButton.create(
                    icon: IaSpace.favIcon,
                    title: IaSpace.defaultPrettyName,
                    subtitle: NSLocalizedString("Connect to a free public \nor paid private server", comment: ""),
                    target: self,
                    action: #selector(newIa),
                    container: container,
                    above: button,
                    equalHeight: true)
            }
            
        }
        
        button.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16).isActive = true
    }
    
    
    // MARK: Actions
    
    @IBAction func newWebDav() {
        navigationController?.pushViewController(UIStoryboard.main.instantiate(WebDavWizardViewController.self),animated: true)
    }
    
    @IBAction func newIa() {
        navigationController?.pushViewController(InternetArchiveLoginViewController(),animated: true)
        
    }
    
    @IBAction func newGdrive() {
        delegate?.next(UIStoryboard.main.instantiate(GdriveWizardViewController.self), pos: 1)
    }
}

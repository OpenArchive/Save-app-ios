//
//  DropboxWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 24.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftyDropbox

class DropboxWizardViewController: BaseViewController, WizardDelegatable {

    weak var delegate: WizardDelegate?

    @IBOutlet weak var iconIv: UIImageView! {
        didSet {
            iconIv.image = .dropboxIcon
                .resizeFit(to: .icon)?
                .withRenderingMode(.alwaysTemplate)
        }
    }

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = DropboxSpace.defaultPrettyName
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = String(
                format: NSLocalizedString("Sign in with %@.",
                                          comment: "Placeholder is 'Dropbox'"),
                DropboxSpace.defaultPrettyName)
        }
    }

    @IBOutlet weak var backBt: UIButton! {
        didSet {
            backBt.setTitle(NSLocalizedString("Back", comment: ""))
        }
    }

    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle(NSLocalizedString("Authenticate", comment: ""))
        }
    }


    @IBAction func back() {
        delegate?.back()
    }

    @IBAction func next() {
        DropboxClientsManager.authorizeFromControllerV2(
            UIApplication.shared,
            controller: self,
            loadingStatusDelegate: nil,
            openURL: { UIApplication.shared.open($0, options: [:]) },
            scopeRequest: ScopeRequest(scopeType: .user, scopes: [], includeGrantedScopes: false))

        // Will continue in AppDelegateBase, where we receive a callback.
    }
}

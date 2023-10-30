//
//  SettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.10.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import UIImage_Resize

class SettingsViewController: UIViewController {

    @IBOutlet weak var generalBt: UIButton! {
        didSet {
            generalBt.setTitle(NSLocalizedString("General", comment: ""))
        }
    }

    @IBOutlet weak var serverBt: UIButton!

    @IBOutlet weak var folderBt: UIButton! {
        didSet {
            folderBt.setTitle(NSLocalizedString("Folder", comment: ""))
        }
    }

    @IBOutlet weak var aboutLb: UILabel! {
        didSet {
            aboutLb.text = String(format: NSLocalizedString("About %@", comment: ""), Bundle.main.displayName)
        }
    }

    @IBOutlet weak var privacyPolicyLb: UILabel! {
        didSet {
            privacyPolicyLb.text = NSLocalizedString("Privacy Policy", comment: "")
        }
    }

    @IBOutlet weak var versionLb: UILabel! {
        didSet {
            versionLb.text = String(format: NSLocalizedString("Version %1$@, build %2$@", comment: ""),
                                    Bundle.main.version, Bundle.main.build)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let space = SelectedSpace.space
        let icon = (space?.favIcon ?? SelectedSpace.defaultFavIcon)?
            .resizedImageToFit(in: CGSize(width: 24, height: 24), scaleIfSmaller: true)

        serverBt.setImage(icon)
        serverBt.setTitle(space?.prettyName ?? NSLocalizedString("Server", comment: ""))
    }

    @IBAction func general() {
        navigationController?.pushViewController(
            GeneralSettingsViewController(), animated: true)
    }

    @IBAction func server() {
        let vc: BaseServerViewController

        switch SelectedSpace.space {
        case is DropboxSpace:
            vc = DropboxViewController()

        case is IaSpace:
            vc = InternetArchiveViewController()

        default:
            vc = PrivateServerViewController()
        }

        vc.space = SelectedSpace.space

        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func folder() {
        navigationController?.pushViewController(FoldersViewController(), animated: true)
    }

    @IBAction func about() {
        if let url = URL(string: "https://open-archive.org/about") {
            UIApplication.shared.open(url, options: [:])
        }
    }

    @IBAction func privacyPolicy() {
        if let url = URL(string: "https://open-archive.org/privacy") {
            UIApplication.shared.open(url, options: [:])
        }
    }
}

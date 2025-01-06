//
//  SettingsViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.10.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    private static let webDavSettingsSegue = "webDavSettingsSegue"
    private static let iaSettingsSegue = "iaSettingsSegue"
    private static let dropboxSettingsSegue = "dropboxSettingsSegue"
    private static let gdriveSettingsSegue = "gdriveSettingsSegue"

    @IBOutlet weak var generalBt: UIButton! {
        didSet {
            generalBt.setImage(nil)
            generalBt.setTitle(NSLocalizedString("General", comment: ""))
        }
    }

    @IBOutlet weak var serverIv: UIImageView!

    @IBOutlet weak var serverBt: UIButton! {
        didSet {
            serverBt.setImage(nil)
            serverBt.accessibilityIdentifier = "btServer"
        }
    }

    @IBOutlet weak var folderBt: UIButton! {
        didSet {
            folderBt.setImage(nil)
            folderBt.setTitle(NSLocalizedString("Folder", comment: ""))
            folderBt.accessibilityIdentifier = "btFolder"
        }
    }

    @IBOutlet weak var aboutLb: UILabel! {
        didSet {
            aboutLb.attributedText = String(
                format: NSLocalizedString("About %@", comment: ""), Bundle.main.displayName)
            .attributed
            .link(into: aboutLb)
        }
    }

    @IBOutlet weak var privacyPolicyLb: UILabel! {
        didSet {
            privacyPolicyLb.attributedText = NSLocalizedString("Privacy Policy", comment: "")
                .attributed
                .link(into: aboutLb)
        }
    }

    @IBOutlet weak var versionLb: UILabel! {
        didSet {
            versionLb.text = String(format: NSLocalizedString("Version %1$@, build %2$@", comment: ""),
                                    Bundle.main.version, Bundle.main.build)

            let gr = UITapGestureRecognizer(target: self, action: #selector(toggleEasterEgg))
            versionLb.addGestureRecognizer(gr)

            versionLb.isUserInteractionEnabled = true
        }
    }

    private var counter = 0

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reload()
    }


    // MARK: Public Methods

    func reload() {
        let space = SelectedSpace.space

        if let icon = space?.favIcon?.resizeFit(to: .icon) {
            serverIv.image = icon.withRenderingMode(space is WebDavSpace || space is GdriveSpace ? .alwaysOriginal : .alwaysTemplate)
        }
        else if let icon = SelectedSpace.defaultFavIcon?.resizeFit(to: .icon) {
          //  serverIv.image = icon.withRenderingMode(.alwaysTemplate)
        }
        else {
            serverIv.image = UIImage(systemName: "server.rack")?.withRenderingMode(.alwaysTemplate)
        }

     //   serverBt.setTitle(space?.prettyName ?? NSLocalizedString("Server", comment: ""))
    }


    // MARK: Actions

    @IBAction func general() {
        navigationController?.pushViewController(
            GeneralSettingsViewController(), animated: true)
    }

    @IBAction func server() {
        var segue: String? = nil

        switch SelectedSpace.space {
        case let space as IaSpace:
            self.navigationController?.pushViewController(InternetArchiveDetailsController(space: space), animated: true)
            //segue = Self.iaSettingsSegue

        case is GdriveSpace:
            segue = Self.gdriveSettingsSegue

        case is WebDavSpace:
            segue = Self.webDavSettingsSegue

        default:
            segue = nil
        }

        if let segue = segue {
            performSegue(withIdentifier: segue, sender: nil)
        }
    }

    @IBAction func folder() {
     //   navigationController?.pushViewController(FoldersViewController(), animated: true)
    }

    @IBAction func about() {
        if let url = URL(string: "https://open-archive.org/save") {
            UIApplication.shared.open(url, options: [:])
        }
    }

    @IBAction func privacyPolicy() {
        if let url = URL(string: "https://open-archive.org/privacy") {
            UIApplication.shared.open(url, options: [:])
        }
    }

    @IBAction func toggleEasterEgg() {
//        counter += 1
//
//        if counter > 2 {
//            Settings.easterEgg = !Settings.easterEgg
//
//            AlertHelper.present(self, message: Settings.easterEgg ? "enabled" : "disabled",
//                                title: "Easter Egg")
//
//            counter = 0
//        }
    }
}

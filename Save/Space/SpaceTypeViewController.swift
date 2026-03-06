//
//  SpaceTypeViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class SpaceTypeViewController: UIHostingController<SpaceTypeView>, WizardDelegatable {

    weak var delegate: WizardDelegate?

    required init() {
        let placeholder = SpaceTypeView(
            showInternetArchive: false,
            onWebDav: {},
            onInternetArchive: {}
        )
        super.init(rootView: placeholder)
        title = NSLocalizedString("Select a Server", comment: "")
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        var showIA = false
        Db.bgRwConn?.read { tx in
            if tx.find(where: { (_: IaSpace) in true }) == nil {
                showIA = true
            }
        }

        rootView = SpaceTypeView(
            showInternetArchive: showIA,
            onWebDav: { [weak self] in self?.newWebDav() },
            onInternetArchive: { [weak self] in self?.newIa() }
        )
    }

    private func newWebDav() {
        navigationController?.pushViewController(
            UIStoryboard.main.instantiate(WebDavWizardViewController.self),
            animated: true)
    }

    private func newIa() {
        navigationController?.pushViewController(
            InternetArchiveLoginViewController(),
            animated: true)
    }
    
    @IBAction func newStoracha() {
        navigationController?.pushViewController(StorachaSettingViewController(),animated: true)
        
    }
}

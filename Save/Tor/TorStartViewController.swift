//
//  TorStartViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 14.03.24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit
import TorManager
import IPtProxyUI
import OrbotKit

class TorStartViewController: UIViewController, BridgesConfDelegate {

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = String(format: NSLocalizedString("Starting %@…", comment: "Placeholder is 'Tor'"), TorManager.torName)
        }
    }

    @IBOutlet weak var progress: UIProgressView!

    @IBOutlet weak var errorLb: UILabel!
    @IBOutlet weak var retryBt: UIButton!

    @IBOutlet weak var configBt: UIButton! {
        didSet {
            configBt.setTitle(NSLocalizedString("Bridge Configuration", bundle: .iPtProxyUI, comment: "#bc-ignore!"))
        }
    }

    @IBOutlet weak var stopBt: UIButton! {
        didSet {
            stopBt.setTitle(String(format: NSLocalizedString("Stop Using %@", comment: "Placeholder is 'Tor'"), TorManager.torName))
        }
    }


    private var requestOrbotApi = false


    override func viewDidLoad() {
        super.viewDidLoad()

        retry()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)
    }


    // MARK: Actions

    @IBAction func retry() {
        progress.progress = 0

        if requestOrbotApi {
            OrbotManager.shared.requestToken { [weak self] in
                OrbotKit.shared.apiToken = Settings.orbotApiToken

                self?.requestOrbotApi = false
                self?.retry()
            }

            return
        }

        errorLb.isHidden = true
        retryBt.isHidden = true

        TorManager.shared.start(
            smartConnect: true,
            { [weak self] progress in
                DispatchQueue.main.async {
                    self?.progress.setProgress(Float(progress) / 100, animated: true)
                }
            },
            { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorLb.text = error.localizedDescription
                        self?.errorLb.isHidden = false
                        self?.retryBt.isHidden = false

                        if case TorManager.Errors.orbotRunningNoBypass = error {
                            self?.retryBt.setTitle(NSLocalizedString("Request API Access", comment: ""))
                            self?.requestOrbotApi = true
                        }
                        else {
                            self?.retryBt.setTitle(NSLocalizedString("Retry", comment: ""))
                            self?.requestOrbotApi = false
                        }
                    }
                    else {
                        self?.dismiss()
                    }
                }
            })
    }

    @IBAction func configure() {
        let vc = BridgesConfViewController()
        vc.delegate = self

        let navC = UINavigationController(rootViewController: vc)

        present(navC, animated: true)
    }

    @IBAction func stop() {
        TorManager.shared.stop()

        Settings.useTor = false

        dismiss()
    }


    // MARK: BridgesConfDelegate

    var transport: IPtProxyUI.Transport {
        get {
            IPtProxyUI.Settings.transport
        }
        set {
            IPtProxyUI.Settings.transport = newValue
        }
    }

    var customBridges: [String]? {
        get {
            IPtProxyUI.Settings.customBridges
        }
        set {
            IPtProxyUI.Settings.customBridges = newValue
        }
    }

    func save() {
        DispatchQueue.global(qos: .userInitiated).async {
            TorManager.shared.reconfigureBridges()
        }
    }


    // MARK: Private Methods

    private func dismiss() {
        if let navC = navigationController as? MainNavigationController {
            navC.setRoot()
        }
    }
}

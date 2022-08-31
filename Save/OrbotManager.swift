//
//  OrbotManager.swift
//  Save
//
//  Created by Benjamin Erhart on 23.06.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import OrbotKit
import YapDatabase

extension Notification.Name {

    static let orbotStopped = Notification.Name("\(Bundle.main.bundleIdentifier!).orbotStopped")
}

class OrbotManager: OrbotStatusChangeListener {

    static let shared = OrbotManager()

    static let appStoreLink = URL(string: "itms-apps://apple.com/app/id1609461599")!


    var installed: Bool {
        OrbotKit.shared.installed
    }

    var status: OrbotKit.Info.Status {
        lastOrbotInfo.status
    }


    private var lastOrbotInfo = OrbotKit.Info(status: .stopped)

    private weak var tokenAlert: UIAlertController?


    // MARK: Public Methods

    func start() {
        OrbotKit.shared.apiToken = Settings.orbotApiToken

        var error: Error?

        let group = DispatchGroup()
        group.enter()

        OrbotKit.shared.info { info, e in
            if let info = info {
                self.lastOrbotInfo = info
            }

            error = e

            group.leave()
        }

        group.wait()

        if let error = error {
            if case OrbotKit.Errors.httpError(statusCode: 403) = error {
                self.alertToken()
            }
            else {
                alert(error: error)
            }
        }
        else {
            OrbotKit.shared.notifyOnStatusChanges(self)
        }
    }

    func stop() {
        OrbotKit.shared.removeStatusChangeListener(self)
    }

    func alert(error: Error) {
        guard let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top else {
            return
        }

        AlertHelper.present(topVc, message: error.friendlyMessage)
    }

    func alertOrbotNotInstalled() {
        guard let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top else {
            return
        }

        AlertHelper.present(
            topVc,
            message: NSLocalizedString("In order to use Orbot, you will first need to install it!", comment: ""),
            title: NSLocalizedString("Orbot not installed", comment: ""),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.defaultAction(NSLocalizedString("App Store", comment: ""), handler: { _ in
                    UIApplication.shared.open(OrbotManager.appStoreLink)
                })])
    }

    func alertToken(_ onSuccess: (() -> Void)? = nil) {
        guard let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top else {
            return
        }

        var urlc: URLComponents?

        if let urlType = (Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]])?.first {
            if let scheme = (urlType["CFBundleURLSchemes"] as? [String])?.first {
                urlc = URLComponents()
                urlc?.scheme = scheme
                urlc?.path = "token-callback"
            }
        }

        AlertHelper.present(
            topVc,
            message: String(
                format: NSLocalizedString(
                    "You need to request API access with Orbot, in order for %@ to ensure that Orbot is running.",
                    comment: ""),
                Bundle.main.displayName),
            title: NSLocalizedString("Orbot installed", comment: ""),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.defaultAction(NSLocalizedString("Request API Access", comment: ""), handler: { [weak self] _ in

                    OrbotKit.shared.open(.requestApiToken(callback: urlc?.url)) { success in
                        if !success {
                            AlertHelper.present(topVc, message: NSLocalizedString("Orbot could not be opened!", comment: ""))
                        }
                        else {
                            self?.tokenAlert = AlertHelper.build(title: NSLocalizedString("Access Token", comment: ""), actions: [AlertHelper.cancelAction()])

                            if let alert = self?.tokenAlert {
                                AlertHelper.addTextField(alert, placeholder: NSLocalizedString("Paste API token here", comment: ""))

                                alert.addAction(AlertHelper.defaultAction() { _ in
                                    Settings.orbotApiToken = self?.tokenAlert?.textFields?.first?.text ?? ""

                                    if !Settings.orbotApiToken.isEmpty {
                                        onSuccess?()
                                    }
                                })

                                topVc.present(alert, animated: false)
                            }
                        }
                    }
                })])
    }

    func received(token: String) {
        tokenAlert?.textFields?.first?.text = token
    }

    /**
     Shows an alert, if

     - app is set up to only use Orbot,
     - Orbot is *not* running,
     - there are uploads in the queue.

     - parameter count: Number of uploads in the queue. If `nil`, method will try find out itself. Beware of database issues when crossing threads!
     - parameter completed: Callback after user interaction or immediately, when no alert is shown.
     */
    func alertOrbotStopped(count: UInt? = nil, _ completed: (() -> Void)? = nil) {
        guard Settings.useOrbot && status == .stopped,
              let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top
        else {
            completed?()

            return
        }

        var ownCount = count ?? 0

        if count == nil {
            Db.bgRwConn?.read { transaction in
                ownCount = transaction.numberOfKeys(inCollection: Upload.collection)
            }
        }

        guard ownCount > 0 else {
            completed?()

            return
        }

        AlertHelper.present(
            topVc,
            message: NSLocalizedString("Uploads are blocked until you start Orbot or allow uploads without Orbot again.", comment: ""),
            title: NSLocalizedString("Orbot not running", comment: ""),
            actions: [
                AlertHelper.cancelAction(NSLocalizedString("Ignore", comment: ""), handler: { _ in
                    completed?()
                }),
                AlertHelper.defaultAction(NSLocalizedString("Start Orbot", comment: ""), handler: { _ in
                    OrbotKit.shared.open(.start)

                    completed?()
                }),
                AlertHelper.destructiveAction(NSLocalizedString("Allow without Orbot", comment: ""), handler: { [weak self] _ in
                    Settings.useOrbot = false

                    self?.stop()

                    completed?()
                })
            ])
    }


    // MARK: OrbotStatusChangeListener

    func orbotStatusChanged(info: OrbotKit.Info) {
        lastOrbotInfo = info

        if status == .stopped {
            NotificationCenter.default.post(name: .orbotStopped, object: nil)
        }
    }

    func statusChangeListeningStopped(error: Error) {
        if case OrbotKit.Errors.httpError(statusCode: 403) = error {
            alertToken()
        }
    }
}

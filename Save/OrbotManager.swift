//
//  OrbotManager.swift
//  Save
//
//  Created by Benjamin Erhart on 23.06.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import OrbotKit
import YapDatabase
import SDCAlertView

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

    private weak var tokenAlert: AlertController?


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
            message: String(format: NSLocalizedString(
                "In order to use %@, you will first need to install it!",
                comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName),
            title: String(format: NSLocalizedString(
                "%@ not installed", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName),
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
                    "You need to request API access with %1$@, in order for %2$@ to ensure that %1$@ is running.",
                    comment: "Placeholder 1 is 'Orbot', placeholder 2 is 'Save'"),
                OrbotKit.orbotName, Bundle.main.displayName),
            title: String(format: NSLocalizedString("%@ installed", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName),
            actions: [
                AlertHelper.cancelAction(),
                AlertHelper.defaultAction(NSLocalizedString("Request API Access", comment: ""), handler: { [weak self] _ in

                    OrbotKit.shared.open(.requestApiToken(callback: urlc?.url)) { success in
                        if !success {
                            AlertHelper.present(topVc, message: String(format: NSLocalizedString(
                                "%@ could not be opened!", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName))
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
     Shows an alert, if there are uploads in the queue AND (
        app is set up to only upload via Wi-Fi OR (
            app is set up to only use Orbot AND Orbot is *not* running
        )
     ).

     - parameter count: Number of uploads in the queue. If `nil`, method will try find out itself. Beware of database issues when crossing threads!
     - parameter completed: Callback after user interaction or immediately, when no alert is shown.
     */
    func alertCannotUpload(count: Int? = nil, _ completed: (() -> Void)? = nil) {
        guard (Settings.wifiOnly && UploadManager.shared.reachability?.connection == .unavailable)
                || (Settings.useOrbot && status == .stopped),
              let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top
        else {
            completed?()

            return
        }

        var ownCount = count ?? 0

        if count == nil {
            Db.bgRwConn?.read { tx in
                ownCount = UploadsView.countUploading(tx)
            }
        }

        guard ownCount > 0 else {
            completed?()

            return
        }

        let message: String
        let title: String
        var actions = [
            AlertHelper.cancelAction(NSLocalizedString("Ignore", comment: ""), handler: { _ in
                completed?()
            })]

        if Settings.wifiOnly {
            message = NSLocalizedString(
                "Uploads are blocked until you connect to a Wi-Fi network or allow uploads over a mobile connection again.",
                comment: "") + "\n" // Ugly fix for text which is slightly cut off in English in the SDCAlertview due to its use of a UIScrollView container.

            title = NSLocalizedString("Wi-Fi not connected", comment: "")

            actions.append(
                AlertHelper.destructiveAction(NSLocalizedString("Allow any connection", comment: ""), handler: { _ in
                    Settings.wifiOnly = false

                    NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)

                    completed?()
                }))
        }
        else {
            message = String(format: NSLocalizedString(
                "Uploads are blocked until you start %1$@ or allow uploads without %1$@ again.",
                comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)

            title = String(format: NSLocalizedString("%@ not running", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)

            actions.append(
                AlertHelper.defaultAction(
                    String(format: NSLocalizedString(
                        "Start %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName),
                    handler: { _ in
                        OrbotKit.shared.open(.start(callback: nil))

                        completed?()
                    }))

            actions.append(
                AlertHelper.destructiveAction(
                    String(format: NSLocalizedString(
                        "Allow without %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName),
                    handler: { [weak self] _ in
                        Settings.useOrbot = false

                        self?.stop()

                        completed?()
                    }))
        }

        AlertHelper.present(topVc, message: message, title: title, actions: actions)
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

//
//  SceneDelegate.swift
//  Save
//
//  Created for UIKit scene-based life cycle migration.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var hadResigned = false
    private var captureChangeToken: NSObjectProtocol?

    static var current: SceneDelegate? {
        UIApplication.shared.connectedScenes
            .compactMap { $0.delegate as? SceneDelegate }
            .first
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let nav = MainNavigationController()
        let newWindow = UIWindow(windowScene: windowScene)
        newWindow.rootViewController = nav
        newWindow.tintColor = .accent
        window = newWindow
        newWindow.makeKeyAndVisible()

        // Apply saved theme (window exists now; didFinishLaunching runs before scene exists)
        (UIApplication.shared.delegate as? AppDelegateBase)?.applyTheme(AppSettings.theme)

        captureChangeToken = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncCapturePrivacyOverlay()
        }
        syncCapturePrivacyOverlay()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let captureChangeToken {
            NotificationCenter.default.removeObserver(captureChangeToken)
            self.captureChangeToken = nil
        }
        BlurredSnapshot.setCapturePrivacyEnabled(false, window: nil)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        if AppSettings.passcodeEnabled {
            BlurredSnapshot.create(window)
            hadResigned = true
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        trackEvent(.appBackgrounded)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        UploadManager.shared.restart()
        if shouldShowAppPasscodeEntryScreen() {
            showAppPasscodeEntryScreen()
        } else {
            AppUpdateManager.shared.checkForUpdateIfNeeded()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        trackEvent(.appForegrounded)
        MainScreenRefreshService.shared.refreshMainMediaState()
        if AppSettings.passcodeEnabled {
            BlurredSnapshot.remove()
        }
        syncCapturePrivacyOverlay()
        maybePromptForReview()
    }

    private func syncCapturePrivacyOverlay() {
        guard AppSettings.passcodeEnabled else {
            BlurredSnapshot.setCapturePrivacyEnabled(false, window: nil)
            return
        }
        let captured = window?.windowScene?.screen.isCaptured ?? false
        BlurredSnapshot.setCapturePrivacyEnabled(captured, window: window)
    }

    // MARK: - Passcode

    func showAppPasscodeEntryScreen() {
        guard let rootVC = window?.rootViewController else { return }

        if let presented = rootVC.presentedViewController,
           presented is UIHostingController<PasscodeEntryView> {
            return
        }

        let onPasscodeSuccess = {
            rootVC.dismiss(animated: true) {
                #if DEBUG
                print("Passcode verified successfully!")
                #endif
                AppUpdateManager.shared.checkForUpdateIfNeeded()
            }
        }

        let onExit = {
            #if DEBUG
            print("Exiting the application...")
            #endif
            UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }

        let passcodeEntryView = PasscodeEntryView(
            onPasscodeSuccess: onPasscodeSuccess,
            onExit: onExit
        )

        let hostingController = UIHostingController(rootView: passcodeEntryView)
        hostingController.modalPresentationStyle = .fullScreen
        rootVC.present(hostingController, animated: true)
    }

    func shouldShowAppPasscodeEntryScreen() -> Bool {
        AppSettings.passcodeEnabled
    }
}

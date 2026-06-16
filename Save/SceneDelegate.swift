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
        // Request extra runtime before iOS suspends us (must be on main, not async).
        UploadManager.shared.prepareForPossibleBackground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        trackEvent(.appBackgrounded)
        UploadManager.shared.willEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        if shouldShowAppPasscodeEntryScreen() {
            showAppPasscodeEntryScreen()
        } else {
            AppUpdateManager.shared.checkForUpdateIfNeeded()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        UploadManager.noteUserForegrounded()
        UploadManager.shared.setBackgroundState(false)
        UploadManager.shared.becameActive()

        trackEvent(.appForegrounded)

        // Defer UI refresh so main thread is free for upload queue callbacks (avoids deadlock).
        DispatchQueue.main.async { [weak self] in
            MainScreenRefreshService.shared.refreshMainMediaState()
            if AppSettings.passcodeEnabled {
                BlurredSnapshot.remove()
            }
            self?.syncCapturePrivacyOverlay()
            maybePromptForReview()
        }
    }

    func syncCapturePrivacyOverlay() {
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

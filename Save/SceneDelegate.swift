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

    static var current: SceneDelegate? {
        UIApplication.shared.connectedScenes
            .compactMap { $0.delegate as? SceneDelegate }
            .first
    }

    private var mainVc: MainViewController? {
        var vc = window?.rootViewController

        while vc != nil {
            if let mainVc = vc as? MainViewController {
                return mainVc
            }

            vc = vc?.subViewController
        }

        return nil
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // With UISceneStoryboardFile, the system creates the window
        window = windowScene.windows.first
        window?.tintColor = .accent

        // Apply saved theme (window exists now; didFinishLaunching runs before scene exists)
        (UIApplication.shared.delegate as? AppDelegateBase)?.applyTheme(AppSettings.theme)
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
        mainVc?.updateFilter()
        if AppSettings.passcodeEnabled {
            BlurredSnapshot.remove()
        }
        maybePromptForReview()
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

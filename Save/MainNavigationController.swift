//
//  MainNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/// Root navigation uses `UINavigationController`. `MainHostingController` hides the system bar (SwiftUI chrome);
/// deeper flows remain UIKit-navigated until a `NavigationStack` window root lands.
class MainNavigationController: UINavigationController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        AppNavigationRouter.shared.navigationController = self
        delegate = self
        setRoot()
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let hideChrome = viewController is MainHostingController
            || viewController is ClaimViewController
            || viewController is OnboardingViewController
        navigationController.setNavigationBarHidden(hideChrome, animated: animated)
        if !hideChrome {
            UINavigationBar.save_applyTealChrome(to: navigationController.navigationBar)
        }

        if #available(iOS 26.0, *) {
            hideGlassBackground(on: viewController)
        }
    }

    @available(iOS 26.0, *)
    private func hideGlassBackground(on viewController: UIViewController) {
        let hidesSystemChrome = viewController is MainHostingController
            || viewController is ClaimViewController
            || viewController is OnboardingViewController
        guard !hidesSystemChrome else { return }
        viewController.save_hidesSharedBackgroundOnNavigationBarButtons()
    }

    func setRoot() {
        if Settings.firstRunDone {
             if !(topViewController is MainHostingController) {
                setViewControllers([MainHostingController()],
                                   animated: true)
            }
        }
        else {
            setViewControllers(
                [ClaimViewController()],
                animated: true)
        }
        
        DispatchQueue.main.async {
            if let sceneDelegate = SceneDelegate.current {
                if sceneDelegate.shouldShowAppPasscodeEntryScreen() {
                    sceneDelegate.showAppPasscodeEntryScreen()
                } else {
                    AppUpdateManager.shared.checkForUpdateIfNeeded()
                }
            }
        }
    }
}

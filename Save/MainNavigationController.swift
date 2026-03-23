//
//  MainNavigationController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 24.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class MainNavigationController: UINavigationController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setRoot()
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if #available(iOS 26.0, *) {
            hideGlassBackground(on: viewController)
        }
    }

    @available(iOS 26.0, *)
    private func hideGlassBackground(on viewController: UIViewController) {
        // Only hide glass on MainViewController's logo and menu buttons
        // Other view controllers (PreviewViewController, BrowseViewController) keep the glass effect
        if viewController is MainViewController {
            viewController.navigationItem.leftBarButtonItems?.forEach { $0.hidesSharedBackground = true }
            viewController.navigationItem.rightBarButtonItems?.forEach { $0.hidesSharedBackground = true }
        }
    }

    func setRoot() {
        if Settings.firstRunDone {
//            if Settings.useTor && !TorManager.shared.connected {
//                setViewControllers([UIStoryboard.main.instantiate(TorStartViewController.self)],
//                                   animated: true)
//            }
             if !(topViewController is MainViewController) {
                setViewControllers([UIStoryboard.main.instantiate(MainViewController.self)],
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

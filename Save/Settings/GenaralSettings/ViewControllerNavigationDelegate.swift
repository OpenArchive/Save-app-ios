//
//  ViewControllerNavigationDelegate.swift
//  Save
//

import UIKit

/// Lets SwiftUI-driven settings (`SettingsViewModel`) push UIKit screens onto the main navigation stack.
protocol ViewControllerNavigationDelegate: AnyObject {
    func pushViewController(_ viewController: UIViewController)
    func pushServerList()
    func pushFolderList()
}

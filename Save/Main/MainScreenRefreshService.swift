//
//  MainScreenRefreshService.swift
//  Save
//
//  Foreground / share-extension refresh via `MainScreenRootRegistry` (no nav stack scan for a concrete VC type).
//

import UIKit

final class MainScreenRefreshService {

    static let shared = MainScreenRefreshService()

    private init() {}

    /// Rebuilds grouping and media grid when the app becomes active.
    func refreshMainMediaState() {
        MainScreenRootRegistry.shared.refreshMainMediaFilter()
    }

    /// Share-extension notification: select project, refresh, open preview.
    func applyShareExtensionProject(_ project: Project, completion: @escaping () -> Void) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let navVc = window?.rootViewController as? UINavigationController else {
            completion()
            return
        }

        AppNavigationRouter.shared.navigationController = navVc

        MainScreenRootRegistry.shared.applyShareExtensionProject(project, navigationController: navVc, completion: completion)
    }
}

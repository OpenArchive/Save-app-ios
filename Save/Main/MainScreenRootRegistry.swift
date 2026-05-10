//
//  MainScreenRootRegistry.swift
//  Save
//
//  Weak registry so foreground refresh and share-extension handoff do not depend on `MainHostingController` lookup by type in the nav stack.
//

import UIKit

/// Bridges system-level callbacks to the active main screen without scanning `viewControllers`.
final class MainScreenRootRegistry {

    static let shared = MainScreenRootRegistry()

    private init() {}

    private weak var root: MainHostingController?

    func register(_ controller: MainHostingController) {
        root = controller
    }

    func unregister(_ controller: MainHostingController) {
        if root === controller {
            root = nil
        }
    }

    func refreshMainMediaFilter() {
        root?.refreshMainMediaFilter()
    }

    /// Share extension: pop to main, select project, refresh, open preview.
    func applyShareExtensionProject(_ project: Project, navigationController nav: UINavigationController, completion: @escaping () -> Void) {
        guard let main = root, nav.viewControllers.contains(where: { $0 === main }) else {
            completion()
            return
        }
        nav.popToViewController(main, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            main.selectedProject = project
            main.refreshMainMediaFilter()
            main.completeShareExtensionMediaFlow()
        }
        completion()
    }
}

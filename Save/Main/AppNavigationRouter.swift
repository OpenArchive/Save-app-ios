//
//  AppNavigationRouter.swift
//  Save
//
//  Central UIKit navigation entry for hybrid SwiftUI flows.
//

import UIKit

/// Owns the primary `UINavigationController` reference and routes stack operations.
/// Set from `MainNavigationController.viewDidLoad` so it stays valid across pushes.
///
/// **SwiftUI migration:** Most screens are `UIHostingController` roots; preview uses a single host
/// (`PreviewViewController` + `PreviewFlowContainerView`). A future step is a `NavigationStack`-based
/// window root (replacing `UINavigationController` as the primary model) while keeping this router as
/// a thin bridge or migrating call sites to a shared `NavigationPath` / `ObservableObject` coordinator.
final class AppNavigationRouter {

    static let shared = AppNavigationRouter()

    private init() {}

    weak var navigationController: UINavigationController?

    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController?.pushViewController(viewController, animated: animated)
    }

    /// Presents from the topmost visible controller on the main stack.
    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        let presenter = navigationController?.visibleViewController
            ?? navigationController?.topViewController
            ?? navigationController
        presenter?.present(viewController, animated: animated, completion: completion)
    }

    /// Returns to an existing main screen or pushes a new one (legacy recovery path).
    func popToMainViewController(animated: Bool) {
        guard let nav = navigationController else { return }
        if let existing = nav.viewControllers.first(where: { $0 is MainHostingController }) {
            nav.popToViewController(existing, animated: animated)
        } else {
            nav.pushViewController(MainHostingController(), animated: animated)
        }
    }

    func pushSpaceType(animated: Bool = true) {
        push(SpaceTypeViewController(), animated: animated)
    }

    func pushAddFolderFlow(animated: Bool = true) {
        if SelectedSpace.available {
            if SelectedSpace.space is IaSpace {
                push(AddNewFolderHostingController(), animated: animated)
            } else {
                push(AddFolderHostingController(), animated: animated)
            }
        } else {
            push(SpaceTypeViewController(), animated: animated)
        }
    }

    func pushPrivateServerSetting(space: Space, animated: Bool = true) {
        push(PrivateServerSettingViewController(space: space), animated: animated)
    }

    func pushPreview(animated: Bool = true) {
        push(PreviewViewController(), animated: animated)
    }

    func pushInternetArchiveDetails(space: IaSpace, animated: Bool = true) {
        push(InternetArchiveDetailsController(space: space), animated: animated)
    }
}

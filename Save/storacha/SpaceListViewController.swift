import UIKit
import SwiftUI

class SpaceListViewController: UIViewController {
    private var appState: StorachaAppState

    init(appState: StorachaAppState) {
        self.appState = appState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "My Spaces"

        // Hide default back text
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.hidesBackButton = true

        // Custom back button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(customBackTapped)
        )

        if #available(iOS 14.0, *) {
            let hostingController = UIHostingController(
                rootView: SpaceListView(spaceState: appState.spaceState) { [weak self] space in
                    self?.navigateToSpaceDetail(space)
                }
            )
            addChild(hostingController)
            view.addSubview(hostingController.view)
            
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            
            hostingController.didMove(toParent: self)
            hostingController.view.backgroundColor = UIColor.systemBackground
            view.backgroundColor = UIColor.systemBackground
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await appState.spaceState.loadSpaces() }
    }

    private func navigateToSpaceDetail(_ space: StorachaSpace) {
        let fileListVC = FileListViewController(appState: appState, space: space)
            navigationController?.pushViewController(fileListVC, animated: true)
    }

    @objc func customBackTapped() {
        guard let navigationController = navigationController else { return }

        if let existingVC = navigationController.viewControllers.first(where: { $0 is StorachaSettingViewController }) {
            navigationController.popToViewController(existingVC, animated: true)
        } else {
            let newVC = StorachaSettingViewController()
            navigationController.pushViewController(newVC, animated: true)
        }
    }
}

import UIKit
import SwiftUI
import Combine

class SpaceListViewController: UIViewController {
    private var appState: StorachaAppState
    private var cancellables = Set<AnyCancellable>()

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
        title = NSLocalizedString("Spaces", comment: "")

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

        // Setup 401 error observers
        setupErrorObservers()

     
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
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await appState.spaceState.loadSpaces() }
    }

    // MARK: - 401 Error Handling
    private func setupErrorObservers() {
        // Observe unauthorized alert
        appState.spaceState.$showUnauthorizedAlert
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.showUnauthorizedAlert()
                }
            }
            .store(in: &cancellables)
        
        // Observe navigation to login
        appState.spaceState.$shouldNavigateToLogin
            .sink { [weak self] shouldNavigate in
                if shouldNavigate {
                    self?.navigateToLogin()
                }
            }
            .store(in: &cancellables)
    }
    
    private func showUnauthorizedAlert() {
        let message = appState.spaceState.unauthorizedMessage
        let isDelegatedUser = appState.spaceState.isDelegatedUserError
        
        if isDelegatedUser {
            // For delegated users, show "Stay Here" option
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Session Expired", comment: ""),
                message: message,
                primaryButtonTitle: NSLocalizedString("Back to Login", comment: ""),
                primaryButtonAction: { [weak self] in
                    self?.appState.spaceState.handleBackToLoginAction()
                },
                secondaryButtonTitle: NSLocalizedString("Stay Here", comment: ""),
                secondaryButtonAction: { [weak self] in
                    Task {
                        await self?.appState.spaceState.handleStayHereAction()
                    }
                },
                secondaryButtonIsOutlined: true,
                iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                iconTint: .accentColor
            )
            
            present(alertVC, animated: true)
        } else {
            // For regular users, only show "Back to Login"
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Session Expired", comment: ""),
                message: message,
                primaryButtonTitle: NSLocalizedString("Back to Login", comment: ""),
                primaryButtonAction: { [weak self] in
                    self?.appState.spaceState.handleBackToLoginAction()
                },
                iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                iconTint: .orange
            )
            
            present(alertVC, animated: true)
        }
    }
    
    private func navigateToLogin() {
        // Reset navigation state
        appState.spaceState.resetNavigationState()

        // Check if login controller exists in navigation stack
        if let navigationController = navigationController {
            // Try to find StorachaLoginViewController in the stack
            if let loginVC = navigationController.viewControllers.first(where: { $0 is StorachaLoginViewController }) {
                // Pop back to existing login controller
                navigationController.popToViewController(loginVC, animated: true)
            } else {
                // Create and navigate to new login controller
                let loginVC = StorachaLoginViewController()
                navigationController.pushViewController(loginVC, animated: true)
            }
        }
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

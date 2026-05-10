//
//  MainHostingController.swift
//  Save
//
//  Root of the main media shell: single `UIHostingController` + `MainHostView` (no nested hosting). Heavy logic lives in `MainScreenCoordinator`.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI root

struct MainHostView: View {
    let coordinator: MainScreenCoordinator

    var body: some View {
        MainView(
            homeViewModel: coordinator.homeViewModel,
            mediaGridViewModel: coordinator.mediaGridViewModel,
            uiState: coordinator.uiState,
            settingsViewModel: coordinator.settingsViewModel,
            folderAssetCountText: coordinator.folderAssetCountText,
            onTapAdd: { coordinator.add() },
            onLongPressAdd: { coordinator.showAddMenu() },
            onTapSettings: { coordinator.toggleSettings() },
            onTapMedia: { coordinator.hideSettingsFromTab() },
            onSelectAsset: { coordinator.openPreview(for: $0) },
            onLongPressAsset: { coordinator.showSelectMediaBar() },
            onTapAssetWithUpload: { coordinator.handleTapAssetWithUpload(asset: $0, upload: $1) },
            onStartRename: { coordinator.showRename() },
            onSubmitRename: { coordinator.updateName() },
            onCloseRename: { coordinator.hideRename() },
            onStartSelectMedia: { coordinator.onStartSelectMedia() },
            onCloseSelectMedia: { coordinator.onCloseSelectMedia() },
            onRemoveAssets: { coordinator.removeAssets() },
            onArchiveFolder: { coordinator.archiveFolder() },
            onRemoveFolder: { coordinator.removeFolder() },
            onHideMenu: { coordinator.hideMenu() },
            onTapMenu: { coordinator.toggleSideMenuFromBar() }
        )
    }
}

// MARK: - UIKit host

final class MainHostingController: UIHostingController<MainHostView>, AssetPickerDelegate, DoneDelegate, ViewControllerNavigationDelegate {

    let coordinator: MainScreenCoordinator

    lazy var assetPicker = AssetPicker(self)

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    /// Used by share-extension handoff (`MainScreenRootRegistry`).
    var selectedProject: Project? {
        get { coordinator.homeViewModel.selectedProject }
        set { coordinator.homeViewModel.selectedProject = newValue }
    }

    init() {
        let coord = MainScreenCoordinator()
        self.coordinator = coord
        super.init(rootView: MainHostView(coordinator: coord))
        coord.attach(host: self)
        view.backgroundColor = .systemBackground
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        coordinator.prepareDatabaseConnections()
        coordinator.settingsViewModel.delegate = self
        Db.add(observer: self, #selector(yapDatabaseModified))
        NotificationCenter.default.addObserver(self, selector: #selector(spaceUpdated), name: .spaceUpdated, object: nil)
        coordinator.scheduleProofModeLocationPromptIfNeeded()
        MainScreenRootRegistry.shared.register(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coordinator.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        coordinator.trackScreenOnAppear()
    }

    deinit {
        MainScreenRootRegistry.shared.unregister(self)
        NotificationCenter.default.removeObserver(self)
    }

    func refreshMainMediaFilter() {
        coordinator.updateFilter()
    }

    func completeShareExtensionMediaFlow() {
        coordinator.pickedFromAssetPicker()
    }

    // MARK: - AssetPickerDelegate

    var currentCollection: Collection? {
        coordinator.assetPickerCurrentCollection
    }

    func picked() {
        coordinator.pickedFromAssetPicker()
    }

    // MARK: - DoneDelegate

    func done() {
        DispatchQueue.main.async { [weak self] in
            self?.coordinator.doneFromManagement()
        }
    }

    // MARK: - ViewControllerNavigationDelegate

    func pushViewController(_ viewController: UIViewController) {
        coordinator.pushViewController(viewController)
    }

    func pushServerList() {
        coordinator.pushServerList()
    }

    func pushFolderList() {
        coordinator.pushFolderList()
    }

    // MARK: - Notifications

    @objc private func yapDatabaseModified(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.coordinator.handleYapDatabaseModified()
        }
    }

    @objc private func spaceUpdated(_ notification: Notification) {
        coordinator.handleSpaceUpdated()
    }
}

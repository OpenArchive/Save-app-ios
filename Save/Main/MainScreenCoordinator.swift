//
//  MainScreenCoordinator.swift
//  Save
//
//  Orchestration for the main SwiftUI shell (media grid, menu, settings, alerts). `MainHostingController` stays a thin UIKit presenter.
//

import SwiftUI
import UIKit
import YapDatabase

@MainActor
final class MainScreenCoordinator: SideMenuDelegate {

    weak var host: MainHostingController?

    private var isLongPressTapped = false

    private lazy var uploadsReadConn = Db.newLongLivedReadConn()
    private lazy var uploadsMappings = YapDatabaseViewMappings(groups: UploadsView.groups, view: UploadsView.name)
    private lazy var collectionsReadConn = Db.newLongLivedReadConn()
    private lazy var collectionsMappings = CollectionsView.createMappings()
    private lazy var assetsReadConn = Db.newLongLivedReadConn()
    private lazy var assetsMappings = AssetsByCollectionView.createMappings()

    lazy var mediaGridViewModel = MediaGridViewModel(
        assetsReadConn: assetsReadConn,
        collectionsReadConn: collectionsReadConn,
        uploadsReadConn: uploadsReadConn,
        assetsMappings: assetsMappings,
        collectionsMappings: collectionsMappings,
        uploadsMappings: uploadsMappings
    )

    let navigationCoordinator: NavigationCoordinator

    lazy var homeViewModel: HomeViewModel = {
        let spacesConn = Db.newLongLivedReadConn()
        let spacesMappings = YapDatabaseViewMappings(groups: SpacesView.groups, view: SpacesView.name)
        spacesConn?.update(mappings: spacesMappings)
        let sideMenuProjectsConn = Db.newLongLivedReadConn()
        let sideMenuProjectsMappings = YapDatabaseViewMappings(groups: ActiveProjectsView.groups, view: ActiveProjectsView.name)
        return HomeViewModel(
            spacesConn: spacesConn,
            spacesMappings: spacesConn == nil ? nil : spacesMappings,
            projectsConn: sideMenuProjectsConn,
            projectsMappings: sideMenuProjectsMappings,
            coordinator: navigationCoordinator
        )
    }()

    let uiState = MainViewUIState()

    let settingsViewModel = SettingsViewModel()

    private lazy var settingsServerListViewController = ServerListViewController()
    private lazy var settingsFolderListViewController = FolderListNewViewController(archived: true)

    init() {
        navigationCoordinator = NavigationCoordinator()
        navigationCoordinator.delegate = self
    }

    func attach(host: MainHostingController) {
        self.host = host
    }

    var folderAssetCountText: String {
        "  \(Formatters.format(mediaGridViewModel.totalItemCount))  "
    }

    private var selectedProjectId: String? {
        homeViewModel.selectedProjectId
    }

    private func resolveSelectedProject() -> Project? {
        guard let id = selectedProjectId else { return nil }
        if let project: Project = Db.bgRwConn?.object(for: id, in: Project.collection) {
            return project
        }
        return homeViewModel.projects.first(where: { $0.id == id }) ?? SelectedProject.project
    }

    func prepareDatabaseConnections() {
        uploadsReadConn?.update(mappings: uploadsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)
    }

    func refreshGrid() {
        mediaGridViewModel.setSelectedProject(selectedProjectId)
    }

    func updateFilter() {
        ProjectsView.updateGrouping()
        refreshGrid()
    }

    func viewWillAppearRefresh() {
        if let project = SelectedProject.project, project.active {
            homeViewModel.reloadAndSelect(project.id)
            updateProject(project: project)
        } else {
            homeViewModel.reload()
            updateProject()
        }
        isLongPressTapped = false
    }

    func scheduleProofModeLocationPromptIfNeeded() {
        if Settings.proofMode && LocationMananger.shared.status == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                LocationMananger.shared.requestAuthorization()
            }
        }
    }

    // MARK: - MainView actions

    func add() {
        if uiState.isSettingsVisible {
            hideSettings()
        }
        guard selectedProjectId != nil else {
            addFolder()
            return
        }
        guard let host else { return }
        AddInfoAlert.presentIfNeeded(viewController: host) { [weak self] in
            self?.host?.assetPicker.pickMedia()
        }
    }

    func showAddMenu() {
        if uiState.isSettingsVisible {
            hideSettings()
        }
        showMediaPickerSheet()
    }

    private func showMediaPickerSheet() {
        if selectedProjectId == nil {
            if !isLongPressTapped {
                isLongPressTapped = true
                addFolder()
            }
            return
        }

        guard let host, host.presentedViewController == nil else { return }
        let popup = MediaPopupViewController()
        popup.onCameraTap = { [weak host] in host?.assetPicker.openCamera() }
        popup.onGalleryTap = { [weak host] in host?.assetPicker.pickMedia() }
        popup.onFilesTap = { [weak host] in host?.assetPicker.pickDocuments() }
        AppNavigationRouter.shared.present(popup, animated: true)
    }

    func toggleSettings() {
        uiState.isSettingsVisible ? hideSettings() : showSettings()
    }

    private func showSettings() {
        hideMenu()
        uiState.isSettingsVisible = true
        host?.trackScreenViewSafely("Settings")
    }

    private func hideSettings() {
        uiState.isSettingsVisible = false
        host?.trackScreenViewSafely("MediaScreen")
    }

    func hideSettingsFromTab() {
        hideSettings()
    }

    func openPreview(for asset: Asset) {
        guard let collectionId = asset.collection?.id else { return }
        AbcFilteredByCollectionView.updateFilter(collectionId)
        AppNavigationRouter.shared.pushPreview()
    }

    func showSelectMediaBar() {
        toggleMode(newMode: true)
    }

    func handleTapAssetWithUpload(asset: Asset, upload: Upload?) {
        guard let host else { return }
        if let upload, upload.error != nil {
            UploadErrorAlert.present(host, upload)
            return
        }
        presentManagement(from: host)
    }

    private func presentManagement(from host: MainHostingController) {
        guard host.presentedViewController == nil else { return }
        let managementVC = ManagementViewController()
        managementVC.delegate = host
        let nav = UINavigationController(rootViewController: managementVC)
        nav.modalPresentationStyle = .fullScreen
        host.present(nav, animated: true)
    }

    func showRename() {
        uiState.renameText = resolveSelectedProject()?.name ?? ""
        uiState.isRenameVisible = true
    }

    func hideRename() {
        uiState.isRenameVisible = false
    }

    func updateName() {
        guard let host else { return }
        guard !uiState.renameText.isEmpty else {
            CustomAlertPresenter.present(
                CustomAlertPresentationModel(
                    title: NSLocalizedString("Error", comment: ""),
                    message: NSLocalizedString("Folder name cannot be empty", comment: ""),
                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                    primaryButtonAction: {},
                    showCheckbox: false,
                    iconImage: Image("ic_error"),
                    iconTint: .gray
                ),
                from: host
            )
            return
        }

        guard let currentProject = resolveSelectedProject() else { return }
        let exists = Db.bgRwConn?.find(where: { (project: Project) in
            project.spaceId == currentProject.spaceId && project.name == self.uiState.renameText && project.id != currentProject.id
        }) != nil

        guard !exists else {
            CustomAlertPresenter.present(
                CustomAlertPresentationModel(
                    title: NSLocalizedString("Error", comment: ""),
                    message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                    primaryButtonAction: {},
                    showCheckbox: false,
                    iconImage: Image("ic_error")
                ),
                from: host
            )
            return
        }

        currentProject.name = uiState.renameText
        Db.writeConn?.setObject(currentProject)
        hideRename()
        updateProject(project: currentProject)
        AppOverlayState.shared.showToast(message: NSLocalizedString("Folder renamed.", comment: ""))
    }

    func onCloseSelectMedia() {
        hideSelectMedia()
    }

    func onStartSelectMedia() {
        toggleMode(newMode: true)
    }

    func removeAssets() {
        guard let host else { return }
        RemoveAssetAlert.present(host, mediaGridViewModel.selectedAssets()) { [weak self] success in
            guard success else { return }
            self?.toggleMode(newMode: false)
            self?.refreshGrid()
        }
    }

    func archiveFolder() {
        guard let host else { return }
        guard let project = resolveSelectedProject() else { return }
        project.active = false
        Db.writeConn?.setObject(project)
        ProjectsView.updateGrouping()
        CustomAlertPresenter.present(
            CustomAlertPresentationModel(
                title: NSLocalizedString("Success!", comment: ""),
                message: NSLocalizedString("Folder archived successfully.", comment: ""),
                primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                primaryButtonAction: {},
                showCheckbox: false,
                iconImage: Image("check_icon")
            ),
            from: host
        )
    }

    func removeFolder() {
        guard let host else { return }
        guard let project = resolveSelectedProject() else { return }
        RemoveProjectAlert.present(host, project) { success in
            guard success else { return }
            AppOverlayState.shared.showToast(message: NSLocalizedString("Folder removed.", comment: ""))
        }
    }

    func toggleSideMenuFromBar() {
        toggleMenu()
    }

    func handleYapDatabaseModified() {
        refreshGrid()
    }

    func handleSpaceUpdated() {
        homeViewModel.selectedProjectId = nil
        if let space = SelectedSpace.space {
            homeViewModel.applySpaces(homeViewModel.spaces.isEmpty ? [space] : homeViewModel.spaces)
        } else {
            homeViewModel.applySpaces([])
        }
        homeViewModel.reload()
        updateProject()
    }

    func trackScreenOnAppear() {
        if uiState.isSettingsVisible {
            host?.trackScreenViewSafely("Settings")
        } else {
            host?.trackScreenViewSafely("MediaScreen")
        }
    }

    func pickedFromAssetPicker() {
        refreshGrid()
        AppNavigationRouter.shared.pushPreview()
    }

    func doneFromManagement() {
        refreshGrid()
    }

    // MARK: - SideMenuDelegate

    func hideMenu() {
        toggleMenu(false)
    }

    func selected(project: Project?) {
        homeViewModel.selectedProject = project
        toggleMenu(false)
        hideSelectMedia()
        updateProject(project: project)
    }

    func addSpace() {
        toggleMenu(false) { _ in
            AppNavigationRouter.shared.pushSpaceType()
        }
    }

    func addFolder() {
        toggleMode(newMode: false)
        toggleMenu(false) { _ in
            AppNavigationRouter.shared.pushAddFolderFlow()
        }
    }

    func hideSelectMedia() {
        mediaGridViewModel.exitEditMode()
        uiState.isSelectMediaVisible = false
    }

    func pushPrivateServerSetting(space: Space) {
        AppNavigationRouter.shared.pushPrivateServerSetting(space: space)
    }

    // MARK: - ViewControllerNavigationDelegate (called from host)

    func pushViewController(_ viewController: UIViewController) {
        host?.navigationController?.pushViewController(viewController, animated: true)
    }

    func pushServerList() {
        guard let host else { return }
        host.navigationController?.pushViewController(settingsServerListViewController, animated: true)
    }

    func pushFolderList() {
        guard let host else { return }
        host.navigationController?.pushViewController(settingsFolderListViewController, animated: true)
    }

    // MARK: - Private

    private func updateProject(project passedProject: Project? = nil) {
        let project = passedProject ?? resolveSelectedProject()
        if let project {
            mediaGridViewModel.setSelectedProject(project.id)
            uiState.renameText = project.name ?? ""
        } else {
            mediaGridViewModel.setSelectedProject(nil)
        }
    }

    private func toggleMode(newMode: Bool) {
        if newMode {
            mediaGridViewModel.enterEditMode()
            uiState.isSelectMediaVisible = true
        } else {
            mediaGridViewModel.exitEditMode()
            uiState.isSelectMediaVisible = false
        }
    }

    private func toggleMenu() {
        toggleMenu(!homeViewModel.isMenuVisible)
    }

    private func toggleMenu(_ toggle: Bool, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        guard homeViewModel.isMenuVisible != toggle else {
            completion?(true)
            return
        }
        if toggle && !SelectedSpace.available {
            addSpace()
            completion?(true)
            return
        }
        if toggle {
            homeViewModel.reload()
        }
        homeViewModel.animateMenu(show: toggle) {
            completion?(true)
        }
    }

    private func configureNavigationBar() {
        guard let host else { return }
        host.navigationItem.hidesBackButton = true
        host.navigationItem.leftBarButtonItem = nil
        host.navigationItem.rightBarButtonItem = nil
        host.navigationController?.setNavigationBarHidden(true, animated: true)
    }

    func onViewWillAppear() {
        configureNavigationBar()
        viewWillAppearRefresh()
    }

    var assetPickerCurrentCollection: Collection? {
        resolveSelectedProject()?.currentCollection
    }
}

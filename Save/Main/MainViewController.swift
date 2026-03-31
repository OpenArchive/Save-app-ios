import UIKit
import YapDatabase
import SwiftUI
import Combine

class MainViewController: UIViewController, UINavigationControllerDelegate, SideMenuDelegate, AssetPickerDelegate, DoneDelegate {

    private var cancellables = Set<AnyCancellable>()
    private var isLongPressTapped = false

    var selectedProject: Project? {
        get { homeViewModel.selectedProject }
        set { homeViewModel.selectedProject = newValue }
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

    private func refreshGrid() {
        mediaGridViewModel.setSelectedProject(selectedProjectId)
    }

    private lazy var uploadsReadConn = Db.newLongLivedReadConn()
    private lazy var uploadsMappings = YapDatabaseViewMappings(groups: UploadsView.groups, view: UploadsView.name)
    private lazy var collectionsReadConn = Db.newLongLivedReadConn()
    private lazy var collectionsMappings = CollectionsView.createMappings()
    private lazy var assetsReadConn = Db.newLongLivedReadConn()
    private lazy var assetsMappings = AssetsByCollectionView.createMappings()

    private lazy var mediaGridViewModel = MediaGridViewModel(
        assetsReadConn: assetsReadConn,
        collectionsReadConn: collectionsReadConn,
        uploadsReadConn: uploadsReadConn,
        assetsMappings: assetsMappings,
        collectionsMappings: collectionsMappings,
        uploadsMappings: uploadsMappings
    )

    private lazy var homeViewModel: HomeViewModel = {
        let coordinator = NavigationCoordinator(delegate: self)
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
            coordinator: coordinator
        )
    }()

    private let uiState = MainViewUIState()
    private lazy var menuButton: UIBarButtonItem = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "menu_icon"), for: .normal)
        button.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "btMenu"
        let item = UIBarButtonItem(customView: button)
        return item
    }()

    private lazy var assetPicker = AssetPicker(self)

    private lazy var mainHostingController: UIHostingController<MainView> = {
        let view = MainView(
            homeViewModel: homeViewModel,
            mediaGridViewModel: mediaGridViewModel,
            uiState: uiState,
            folderAssetCountText: folderAssetCountText,
            onTapAdd: { [weak self] in self?.add() },
            onLongPressAdd: { [weak self] in self?.showAddMenu() },
            onTapSettings: { [weak self] in self?.toggleSettings() },
            onTapMedia: { [weak self] in self?.hideSettings() },
            onSelectAsset: { [weak self] asset in self?.openPreview(for: asset) },
            onLongPressAsset: { [weak self] in self?.showSelectMediaBar() },
            onTapAssetWithUpload: { [weak self] asset, upload in self?.handleTapAssetWithUpload(asset: asset, upload: upload) },
            onStartRename: { [weak self] in self?.showRename() },
            onSubmitRename: { [weak self] in self?.updateName() },
            onCloseRename: { [weak self] in self?.hideRename() },
            onStartSelectMedia: { [weak self] in self?.toggleMode(newMode: true) },
            onCloseSelectMedia: { [weak self] in self?.hideSelectMedia() },
            onRemoveAssets: { [weak self] in self?.removeAssets() },
            onArchiveFolder: { [weak self] in self?.archiveFolder() },
            onRemoveFolder: { [weak self] in self?.removeFolder() },
            onHideMenu: { [weak self] in self?.hideMenu() }
        )
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = .systemBackground
        return host
    }()

    private var folderAssetCountText: String {
        "  \(Formatters.format(mediaGridViewModel.totalItemCount))  "
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        uploadsReadConn?.update(mappings: uploadsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        addChild(mainHostingController)
        view.addSubview(mainHostingController.view)
        mainHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainHostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            mainHostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainHostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        mainHostingController.didMove(toParent: self)

        Db.add(observer: self, #selector(yapDatabaseModified))
        NotificationCenter.default.addObserver(self, selector: #selector(spaceUpdated), name: .spaceUpdated, object: nil)

        if Settings.proofMode && LocationMananger.shared.status == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                LocationMananger.shared.requestAuthorization()
            }
        }

        mediaGridViewModel.$totalItemCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuButtonVisibility()
            }
            .store(in: &cancellables)

        mediaGridViewModel.$sections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuButtonVisibility()
            }
            .store(in: &cancellables)

        homeViewModel.$selectedProjectId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuButtonVisibility()
            }
            .store(in: &cancellables)

        homeViewModel.$spaces
            .combineLatest(homeViewModel.$currentSpaceIcon)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updateMenuButtonVisibility()
            }
            .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()

        if let project = SelectedProject.project, project.active {
            homeViewModel.reloadAndSelect(project.id)
            // updateProject will call setSelectedProject which calls updateFilter internally
            updateProject(project: project)
        } else {
            homeViewModel.reload()
            updateProject()
        }

        isLongPressTapped = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("MediaScreen")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public integrations
    func updateFilter() {
        ProjectsView.updateGrouping()
        refreshGrid()
    }

    // MARK: SideMenuDelegate
    func hideMenu() {
        toggleMenu(false)
    }

    func selected(project: Project?) {
        selectedProject = project
        toggleMenu(false)
        hideSelectMedia()
        updateProject(project: project)
    }

    func addSpace() {
        toggleMenu(false) { [weak self] _ in
            self?.navigationController?.pushViewController(SpaceTypeViewController(), animated: true)
        }
    }

    func addFolder() {
        toggleMode(newMode: false)
        toggleMenu(false) { [weak self] _ in
            guard let self else { return }
            if SelectedSpace.available {
                if SelectedSpace.space is IaSpace {
                    self.navigationController?.pushViewController(AddNewFolderViewController(), animated: true)
                } else {
                    self.navigationController?.pushViewController(AddFolderViewController(), animated: true)
                }
            } else {
                self.navigationController?.pushViewController(SpaceTypeViewController(), animated: true)
            }
        }
    }

    func hideSelectMedia() {
        mediaGridViewModel.exitEditMode()
        uiState.isSelectMediaVisible = false
    }

    func pushPrivateServerSetting(space: Space) {
        let vc = PrivateServerSettingViewController()
        vc.space = space
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: AssetPickerDelegate
    var currentCollection: Collection? {
        resolveSelectedProject()?.currentCollection
    }

    func picked() {
        refreshGrid()
        showPreview()
    }

    // MARK: DoneDelegate
    func done() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshGrid()
        }
    }

    // MARK: Actions
    private func add() {
        if uiState.isSettingsVisible {
            hideSettings()
        }
        guard selectedProjectId != nil else {
            addFolder()
            return
        }
        AddInfoAlert.presentIfNeeded(viewController: self) {
            self.assetPicker.pickMedia()
        }
    }

    private func showAddMenu() {
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

        guard presentedViewController == nil else { return }
        let popup = MediaPopupViewController()
        popup.onCameraTap = { [weak self] in self?.assetPicker.openCamera() }
        popup.onGalleryTap = { [weak self] in self?.assetPicker.pickMedia() }
        popup.onFilesTap = { [weak self] in self?.assetPicker.pickDocuments() }
        present(popup, animated: true)
    }

    private func toggleSettings() {
        uiState.isSettingsVisible ? hideSettings() : showSettings()
    }

    private func showSettings() {
        hideMenu()
        let settingsVC = GeneralSettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    private func hideSettings() {
        uiState.isSettingsVisible = false
    }

    private func showRename() {
        uiState.renameText = resolveSelectedProject()?.name ?? ""
        uiState.isRenameVisible = true
    }

    private func hideRename() {
        uiState.isRenameVisible = false
    }

    private func updateName() {
        guard !uiState.renameText.isEmpty else {
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Error", comment: ""),
                message: NSLocalizedString("Folder name cannot be empty", comment: ""),
                primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                primaryButtonAction: {},
                showCheckbox: false,
                iconImage: Image("ic_error"),
                iconTint: .gray
            )
            present(alertVC, animated: true)
            return
        }

        guard let currentProject = resolveSelectedProject() else { return }
        let exists = Db.bgRwConn?.find(where: { (project: Project) in
            project.spaceId == currentProject.spaceId && project.name == self.uiState.renameText && project.id != currentProject.id
        }) != nil

        guard !exists else {
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Error", comment: ""),
                message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                primaryButtonAction: {},
                showCheckbox: false,
                iconImage: Image("ic_error")
            )
            present(alertVC, animated: true)
            return
        }

        currentProject.name = uiState.renameText
        Db.writeConn?.setObject(currentProject)
        hideRename()
        updateProject(project: currentProject)
        showToast(message: NSLocalizedString("Folder renamed.", comment: ""))
    }

    private func removeAssets() {
        RemoveAssetAlert.present(self, mediaGridViewModel.selectedAssets()) { [weak self] success in
            guard success else { return }
            self?.toggleMode(newMode: false)
            self?.refreshGrid()
        }
    }

    private func archiveFolder() {
        guard let project = resolveSelectedProject() else { return }
        project.active = false
        Db.writeConn?.setObject(project)
        ProjectsView.updateGrouping()
        let alertVC = CustomAlertViewController(
            title: NSLocalizedString("Success!", comment: ""),
            message: NSLocalizedString("Folder archived successfully.", comment: ""),
            primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
            primaryButtonAction: {},
            showCheckbox: false,
            iconImage: Image("check_icon")
        )
        present(alertVC, animated: true)
    }

    private func removeFolder() {
        guard let project = resolveSelectedProject() else { return }
        RemoveProjectAlert.present(self, project) { [weak self] success in
            guard success else { return }
            self?.showToast(message: NSLocalizedString("Folder removed.", comment: ""))
        }
    }

    // MARK: Preview / upload
    private func showPreview(initialRow: Int? = nil) {
        navigationController?.pushViewController(PreviewViewController(), animated: true)
    }

    private func openPreview(for asset: Asset) {
        guard let collectionId = asset.collection?.id else { return }
        AbcFilteredByCollectionView.updateFilter(collectionId)
        showPreview()
    }

    private func showSelectMediaBar() {
        toggleMode(newMode: true)
    }

    private func handleTapAssetWithUpload(asset: Asset, upload: Upload?) {
        if let upload, upload.error != nil {
            UploadErrorAlert.present(self, upload)
            return
        }
        presentManagement()
    }

    private func presentManagement() {
        guard presentedViewController == nil else { return }
        let managementVC = ManagementViewController()
        managementVC.delegate = self
        let nav = UINavigationController(rootViewController: managementVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: Data updates
    @objc private func yapDatabaseModified(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshGrid()
        }
    }

    @objc private func spaceUpdated(_ notification: Notification) {
        homeViewModel.selectedProjectId = nil
        // Immediately sync space state so the UI updates before the async reload completes.
        if let space = SelectedSpace.space {
            homeViewModel.applySpaces(homeViewModel.spaces.isEmpty ? [space] : homeViewModel.spaces)
        } else {
            homeViewModel.applySpaces([])
        }
        homeViewModel.reload()
        updateProject()
    }

    private func updateProject(project passedProject: Project? = nil) {
        let project = passedProject ?? resolveSelectedProject()
        if let project {
            // setSelectedProject will call updateFilter internally
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

    @objc private func menuButtonTapped() {
        toggleMenu()
    }

    private func configureNavigationBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .menuBackground
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "Montserrat-SemiBold", size: 18) ?? UIFont.systemFont(ofSize: 18),
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white

        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "save_logo_navbar")?.withRenderingMode(.alwaysOriginal),
            style: .plain,
            target: nil,
            action: nil
        )
        navigationItem.rightBarButtonItem = menuButton
        updateMenuButtonVisibility()
    }

    private func updateMenuButtonVisibility() {
        let hasSpace = !homeViewModel.spaces.isEmpty
        menuButton.customView?.isHidden = !hasSpace
    }
}


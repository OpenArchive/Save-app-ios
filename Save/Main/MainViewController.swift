//
//  MainViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import SwiftUI
class MainViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource,
                          UINavigationControllerDelegate, SideMenuDelegate,
                          AssetPickerDelegate,UITextFieldDelegate,UICollectionViewDelegate
{
    
    @IBOutlet weak var renameView: UIView!{
        didSet {
            renameView.isHidden = true
        }
    }
    
    @IBOutlet weak var mediaArrow: UIImageView!
    @IBOutlet weak var EditButtonTrailingContraint: NSLayoutConstraint!
    @IBOutlet weak var titleContainerHeight: NSLayoutConstraint!
    @IBOutlet weak var titleContainer: UIView!
    private static let segueShowPreview = "showPreviewSegue"
    private static let segueShowPrivateServerSetting = "showPrivateServerSetting"
    private static var isSettingsEnabled = false
    lazy var privateServer:Space? = nil
    private var isLongPressTapped: Bool = false
    private let sessionManager = SessionManager.shared
    @IBOutlet weak var logo: UIImageView!
    
    @IBOutlet weak var removeBt: UIButton! {
        didSet {
            removeBt.isHidden = true
        }
    }
    @IBOutlet weak var selectMediaView: UIView!{
        didSet {
            selectMediaView.isHidden = true
        }
    }
    
    @IBOutlet weak var folderIndicator: UIImageView!
    @IBOutlet weak var editButton: UIButton!
    private lazy var menuBt: UIButton = {
        let button: UIButton
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: "menu_icon")
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            button = UIButton(configuration: config, primaryAction: nil)
        } else {
            button = UIButton(type: .system)
            button.setImage(UIImage(named: "menu_icon"), for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
        button.accessibilityIdentifier = "btMenu"
        button.addTarget(self, action: #selector(didTapMenuButton), for: .touchUpInside)
        // Increase tap area without changing icon size
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        return button
    }()
    private lazy var menuBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(customView: menuBt)
    }()
    
    
    @IBOutlet weak var menu: UIView! {
        didSet {
            menu.isHidden = true
        }
    }
    
    @IBOutlet weak var folderNameText: UITextField!
    @IBOutlet weak var spaceFavIcon: UIImageView!
    @IBOutlet weak var folderNameLb: UILabel!
    
    @IBOutlet weak var folderAssetCountLb: UILabel! {
        didSet {
            
            folderAssetCountLb.clipsToBounds = true
        }
    }
    
    @IBOutlet weak var manageBt: UIButton! {
        didSet {
            manageBt.setTitle(NSLocalizedString("Edit", comment: ""))
            manageBt.accessibilityIdentifier = "btManageUploads"
        }
    }
    
    @IBOutlet weak var welcomeLb: UILabel! {
        didSet {
            welcomeLb.font = .montserrat(forTextStyle: .largeTitle, with: .traitBold)
            welcomeLb.textColor = .welcome
            welcomeLb.text = NSLocalizedString("Welcome!", comment: "")
        }
    }
    
    @IBOutlet weak var hintLb: UILabel! {
        didSet {
            hintLb.font = UIFont(name: "Montserrat-Bold", size: 24)
            hintLb.textColor = .mediaSubtitle
            hintLb.text = NSLocalizedString("Press the button below to add media", comment: "")
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var bottomMenu: UIView! {
        didSet {
            // Only round top corners.
            bottomMenu.layer.cornerRadius = 9
            bottomMenu.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
    }
    
    @IBOutlet weak var myMediaBt: UIButton! {
        didSet {
            myMediaBt.setAttributedTitle(.init(
                string: NSLocalizedString("My Media", comment: ""),
                attributes: [.font: UIFont.montserrat(forTextStyle: .caption1)]))
        }
    }
    
    @IBOutlet weak var container: UIView!
    
    @IBOutlet weak var addBt: UIButton! {
        didSet {
            addBt.setTitle("")
        }
    }
    
    
    @IBOutlet weak var settingsBt: UIButton! {
        didSet {
            settingsBt.setAttributedTitle(.init(
                string: NSLocalizedString("Settings", comment: ""),
                attributes: [.font: UIFont.montserrat(forTextStyle: .caption1)]))
            settingsBt.accessibilityIdentifier = "btSettings"
        }
    }
    
    @IBAction func closeRenameView(_ sender: Any) {
        renameView.isHidden = true
    }
    
    
    @IBAction func closeMedia(_ sender: Any) {
        selectMediaView.isHidden = true
        self.toggleMode(newMode: false)
    }
    
    var selectedProject: Project? {
        get {
            homeViewModel.selectedProject
        }
        set {
            homeViewModel.selectedProject = newValue
        }
    }
    
    private lazy var uploadsReadConn = Db.newLongLivedReadConn()
    
    private lazy var uploadsMappings = YapDatabaseViewMappings(
        groups: UploadsView.groups, view: UploadsView.name)
    
    private lazy var collectionsReadConn = Db.newLongLivedReadConn()
    
    private lazy var collectionsMappings = CollectionsView.createMappings()
    
    private lazy var assetsReadConn = Db.newLongLivedReadConn()
    
    private lazy var assetsMappings = AbcFilteredByProjectView.createMappings()

    private var inEditMode = false
    
    
    private lazy var homeViewModel: HomeViewModel = {
        let coordinator = NavigationCoordinator(delegate: self)

        let spacesConn = Db.newLongLivedReadConn()
        let spacesMappings = YapDatabaseViewMappings(
            groups: SpacesView.groups,
            view: SpacesView.name
        )
        spacesConn?.update(mappings: spacesMappings)

        // Create separate connections for side menu to avoid interference
        let sideMenuProjectsConn = Db.newLongLivedReadConn()
        let sideMenuProjectsMappings = YapDatabaseViewMappings(
            groups: ActiveProjectsView.groups, view: ActiveProjectsView.name)

        let viewModel = HomeViewModel(
            spacesConn: spacesConn,
            spacesMappings: spacesConn == nil ? nil : spacesMappings,
            projectsConn: sideMenuProjectsConn,
            projectsMappings: sideMenuProjectsMappings,
            coordinator: coordinator
        )

        return viewModel
    }()

    private lazy var sideMenuHostingController: UIHostingController<SideMenuRootView> = {
        let coordinator = homeViewModel.coordinator

        let contentView = SideMenuRootView(
            homeViewModel: homeViewModel,
            coordinator: coordinator
        )

        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        menu.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.leadingAnchor.constraint(equalTo: menu.leadingAnchor).isActive = true
        hostingController.view.topAnchor.constraint(equalTo: menu.topAnchor).isActive = true
        hostingController.view.trailingAnchor.constraint(equalTo: menu.trailingAnchor).isActive = true
        hostingController.view.bottomAnchor.constraint(equalTo: menu.bottomAnchor).isActive = true

        hostingController.didMove(toParent: self)

        return hostingController
    }()
    
    private lazy var settingsVc: GeneralSettingsViewController = {
        let vc = GeneralSettingsViewController()
        return vc
    }()
    
    private lazy var assetPicker = AssetPicker(self)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        folderNameText.delegate = self
        collectionView.allowsMultipleSelection = true
        uploadsReadConn?.update(mappings: uploadsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)
        Db.add(observer: self, #selector(yapDatabaseModified))

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        if Settings.proofMode && LocationMananger.shared.status == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                LocationMananger.shared.requestAuthorization()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(spaceUpdated), name: .spaceUpdated, object: nil)

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("MediaScreen")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        updateName()
        return true
    }
    
    // MARK: - Update Name
    private func updateName() {
        if(folderNameText.text != ""){
            if let currentProject = selectedProject{
                let isExsists =  Db.bgRwConn?.find(where: { (project:Project) in
                    project.spaceId == currentProject.spaceId && project.name == folderNameText.text && project.id != currentProject.id
                }) != nil
                
                if (isExsists){
                    let alertVC = CustomAlertViewController(
                        title: NSLocalizedString("Error", comment: ""),
                        message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                        primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                        primaryButtonAction: {
                            
                        }, showCheckbox: false, iconImage: Image("ic_error"),
                        
                    )
                    self.present(alertVC, animated: true)
                    
                }else{
                    selectedProject?.name = folderNameText.text
                    Db.writeConn?.setObject(currentProject)
                    renameView.isHidden = true
                    updateProject()
                    showToast(message:  NSLocalizedString("Folder renamed.",comment: ""))
                    
                }
            }}
        else{
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Error", comment: ""),
                message: NSLocalizedString("Folder name cannot be empty", comment: ""),
                primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                primaryButtonAction: {
                    
                }, showCheckbox: false, iconImage: Image("ic_error"),
                iconTint:.gray
            )
            self.present(alertVC, animated: true)
        }
    }
    
    // MARK: - Dismiss Keyboard on Background Tap
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    //MARK: = Dropdown menu
    private func createDropdownMenu() -> UIMenu {
        let isAssetsEmpty = !(numberOfSections(in: collectionView) != 0)
        let renameAction = UIAction(title: NSLocalizedString("Rename folder", comment: ""), image: nil) { _ in
            self.updateProject()
            self.renameView.isHidden = false
            
        }
        
        let selectMediaAction = UIAction(title: NSLocalizedString("Select media", comment: ""), image: nil, attributes: isAssetsEmpty ? [.disabled] : []) { _ in
            self.toggleMode(newMode: true)
        }
        
        let archiveAction = UIAction(title: NSLocalizedString("Archive folder", comment: ""), image: nil) { _ in

            if let project = self.selectedProject{
                project.active = false
                Db.writeConn?.setObject(project)
                self.selectedProject?.active = false

                // Update view grouping to exclude archived project
                ProjectsView.updateGrouping()

                // Database observer will handle selecting the next project

                let alertVC = CustomAlertViewController(
                    title:NSLocalizedString("Success!", comment: "") ,
                    message: NSLocalizedString("Folder archived successfully.", comment: ""),
                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                    primaryButtonAction: {
                        if let navigationController = self.navigationController {

                            if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {

                                navigationController.popToViewController(existingVC, animated: true)
                            } else {

                                let newVC = MainViewController()
                                navigationController.pushViewController(newVC, animated: true)
                            }
                        }
                    },
                    showCheckbox: false,
                    iconImage: Image("check_icon")
                )
                self.present(alertVC, animated: true)
            }
        }
        
        let removeAction = UIAction(title: NSLocalizedString("Remove folder from app", comment: ""), image: nil) { _ in

            if let project = self.selectedProject{
                RemoveProjectAlert.present(self, project, { [weak self] success in
                    guard success else {
                        return
                    }
                    self?.showToast(message:  NSLocalizedString("Folder removed.",comment: ""))
                    // Database observer will handle selecting the next project
                })

            }

        }
        
        return UIMenu(title: "", children: [renameAction, selectMediaAction, archiveAction, removeAction])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let project = SelectedProject.project, project.active {
            selectedProject = project
            homeViewModel.reloadAndSelect(project.id)
            AbcFilteredByProjectView.updateFilter(project.id)
            updateProject(project: project)
        } else {
            homeViewModel.reload()
        }

        uploadsReadConn?.update(mappings: uploadsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        configureNavigationBar()
        updateSpace()
        if SelectedProject.project == nil || !(SelectedProject.project?.active ?? false) {
            updateProject()
        }

        collectionView.reloadData()
        let finalSections = numberOfSections(in: collectionView)
        collectionView.toggle(finalSections != 0, animated: animated)

        isLongPressTapped = false
        if #available(iOS 14.0, *) {
            editButton.menu = createDropdownMenu()
            editButton.showsMenuAsPrimaryAction = true
        }
        if(MainViewController.isSettingsEnabled){
            self.titleContainer.isHidden = true
            self.titleContainerHeight.constant = 0
        }
        if inEditMode && collectionView.numberOfSelectedItems < 1 {
            toggleMode()
        }
        updateManageBt()
    }
 
    
    private func updateDropdownMenu() {
        editButton.menu = createDropdownMenu()
        editButton.showsMenuAsPrimaryAction = true
    }
    @objc private func appDidBecomeActive() {
        if(MainViewController.isSettingsEnabled){
            self.titleContainer.isHidden = true
            self.titleContainerHeight.constant = 0
        }
    }

    @objc private func spaceUpdated(_ notification: Notification) {
        guard let updatedSpace = notification.object as? Space else {
            return
        }

        if SelectedSpace.id == updatedSpace.id {
            SelectedSpace.space = updatedSpace
        }
        // User just switched space - clear selectedProject; observer will select first project
        selectedProject = nil
        updateSpace()
        updateProject()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    private func configureNavigationBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        if #available(iOS 15.0, *) {
            appearance.backgroundColor = .menuBackground
        } else {
            appearance.backgroundColor = .menuBackground
        }
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "Montserrat-SemiBold", size: 18) ??  UIFont.systemFont(ofSize: 18),
        ]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = UIColor.white
        
        configureNavigationBarLogo()
        
    }
    
    @objc private func didTapMenuButton() {
        if menu.isHidden {
            syncMenuSelection()
            _ = sideMenuHostingController
        }

        toggleMenu(menu.isHidden)
    }

    private func syncMenuSelection() {
        homeViewModel.reload()
    }
    private func configureNavigationBarLogo() {
        guard let logoImage = UIImage(named: "save_logo_navbar") else { return }
        
        let logoImageView = UIImageView(image: logoImage)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let logoContainer = UIView()
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor,constant: -10),
            logoImageView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor, constant: 0),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        
        let logoItem = UIBarButtonItem(customView: logoContainer)
        
        navigationItem.leftBarButtonItems = [logoItem]
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }
    
    /**
     Workaround for the filtered view, which potentially got reset by the share
     extension's `Db#setup` call.
     
     Needs to be called from `AppDelegate#applicationWillEnterForeground`.
     */
    func updateFilter() {
        ProjectsView.updateGrouping()
        updateProject()
    }
    
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let noOfCellsInRow = 3
        
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        
        let totalSpace = flowLayout.sectionInset.left
        + flowLayout.sectionInset.right
        + (flowLayout.minimumInteritemSpacing * CGFloat(noOfCellsInRow - 1))
        
        let size = Int((collectionView.bounds.width - totalSpace) / CGFloat(noOfCellsInRow))
        
        return CGSize(width: size, height: size)
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(assetsMappings.numberOfItems(inSection: UInt(section)))
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Int(assetsMappings.numberOfSections())
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind
                        kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: HeaderView.reuseId, for: indexPath) as! HeaderView
        
        let group = assetsMappings.group(forSection: UInt(indexPath.section))
        let collection: Collection? = collectionsReadConn?.object(for: AssetsByCollectionView.collectionId(from: group))
        
        
        collection?.assets.removeAll()
        
        collection?.assets.append(contentsOf: assetsReadConn?.objects(in: indexPath.section, with: assetsMappings) ?? [])
        
        view.collection = collection
        
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseId, for: indexPath) as! ImageCell
        
        let asset: Asset? = assetsReadConn?.object(at: indexPath, in: assetsMappings)
        
        cell.set(asset, !(asset?.isUploaded ?? true) ? uploadsReadConn?.find(where: { $0.assetId == asset?.id }) : nil)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if inEditMode {
            return updateRemove()
        }
        
        if let cell = collectionView.cellForItem(at: indexPath) as? ImageCell {
            if let upload = cell.upload {
                collectionView.deselectItem(at: indexPath, animated: false)
                
                if upload.error != nil {
                    return UploadErrorAlert.present(self, upload)
                }
                performSegue(withIdentifier: "editAssetsSegue", sender: indexPath.row)
                
                return
            }
            
            if cell.asset?.isUploaded ?? false || cell.upload != nil {
                toggleMode(newMode: true)
                
                return updateRemove()
            }
        }
        
        collectionView.deselectItem(at: indexPath, animated: false)
        
        AbcFilteredByCollectionView.updateFilter(AssetsByCollectionView.collectionId(
            from: assetsMappings.group(forSection: UInt(indexPath.section))))
        
        performSegue(withIdentifier: Self.segueShowPreview, sender: indexPath.row)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        // Switch off edit mode, when last item was deselected.
        if collectionView.numberOfSelectedItems < 1 {
            toggleMode(newMode: false)
        }
        else {
            updateRemove()
        }
    }
    
    
    // MARK: SideMenuDelegate
    
    func hideMenu() {
        toggleMenu(false)
    }
    
    func selected(project: Project?) {
        selectedProject = project
        SelectedProject.project = project
        SelectedProject.store()

        toggleMenu(false)

        if AbcFilteredByProjectView.projectId != project?.id {
            toggleMode(newMode: false)
        }
        hideSelectMedia()
        updateProject()
    }
    
    func addSpace() {
        toggleMenu(false) { [weak self] _ in
            self?.navigationController?.pushViewController(SpaceTypeViewController(), animated: true)
        }
    }
    
    func hideSelectMedia() {
        selectMediaView.isHidden = true
        self.toggleMode(newMode: false)
    }
    
    // MARK: Actions
    
    @IBAction func hideSettings() {
        toggleMenu(false) { _ in
            self.container.hide(animated: true) { _ in
                self.settingsVc.view.removeFromSuperview()
                self.settingsVc.removeFromParent()
            }
            self.titleContainer.isHidden = false
            if self.selectedProject == nil {
                self.toggleVisibility(ishidden: true)
            }
            
            self.titleContainerHeight.constant = 44
            self.myMediaBt.setImage(UIImage(named: "media_image"))
            self.settingsBt.setImage(UIImage(systemName: "gearshape"))
            self.settingsBt.tintColor = .white
            self.menuBt.isHidden = false
            MainViewController.isSettingsEnabled=false
            self.updateProject()
        }
    }
    
    @IBAction func showSettings() {
        toggleMenu(false) { _ in
            
            self.container.addSubview(self.settingsVc.view)
            
            self.container.translatesAutoresizingMaskIntoConstraints = false
            self.settingsVc.view.translatesAutoresizingMaskIntoConstraints = false
            
            self.container.topAnchor.constraint(equalTo: self.settingsVc.view.topAnchor).isActive = true
            self.container.bottomAnchor.constraint(equalTo: self.settingsVc.view.bottomAnchor).isActive = true
            self.container.leadingAnchor.constraint(equalTo: self.settingsVc.view.leadingAnchor).isActive = true
            self.container.trailingAnchor.constraint(equalTo: self.settingsVc.view.trailingAnchor).isActive = true
            
            self.addChild(self.settingsVc)
            self.settingsVc.didMove(toParent: self)
            self.titleContainer.isHidden = true
            self.titleContainerHeight.constant = 0
            self.container.show2(animated: true)
            MainViewController.isSettingsEnabled = true
            self.myMediaBt.setImage(UIImage(named: "media_unselected"))
            self.menuBt.isHidden = true
            self.settingsBt.setImage(UIImage(systemName: "gearshape.fill"))
            self.settingsBt.tintColor = .white
        }
    }
    
    @IBAction func toggleMenu() {
        if menu.isHidden {
            syncMenuSelection()
            _ = sideMenuHostingController
        }

        toggleMenu(menu.isHidden)
    }
    
    @IBAction func addFolder() {
        toggleMode(newMode: false)
        
        toggleMenu(false) { _ in
            if SelectedSpace.available {
                if SelectedSpace.space is IaSpace {
                    self.navigationController?.pushViewController(AddNewFolderViewController(), animated: true)
                } else {
                    self.navigationController?.pushViewController(AddFolderViewController(), animated: true)
                }
                
            }
            else {
                self.navigationController?.pushViewController(SpaceTypeViewController(), animated: true)
            }
        }
    }
    
    @IBAction func add() {
        if(MainViewController.isSettingsEnabled){
            hideSettings()
        }
        // Don't allow to add assets without a space or a project.
        if selectedProject == nil {
            return  self.addFolder()
        }
        
        AddInfoAlert.presentIfNeeded(viewController: self) {
            self.assetPicker.pickMedia()
        }
    }
    
    func showMediaPickerSheet() {
        
        if selectedProject == nil {
            if(!isLongPressTapped){
                isLongPressTapped.toggle()
                return addFolder()
            }
        }
        else{
            guard presentedViewController == nil else { return }

            let popup = MediaPopupViewController()
            self.mediaArrow.isHidden = true
            
            popup.onCameraTap = { [weak self] in
                self?.mediaArrow.isHidden = false
                self?.assetPicker.openCamera()
            }
            popup.onGalleryTap = { [weak self] in
                self?.mediaArrow.isHidden = false
                self?.assetPicker.pickMedia()
            }
            popup.onFilesTap = { [weak self] in
                self?.mediaArrow.isHidden = false
                self?.assetPicker.pickDocuments()
            }
            popup.onAppear = { [weak self] in
                self?.mediaArrow.isHidden = true
            }
            popup.onDisappear = { [weak self] in
                self?.mediaArrow.isHidden = false
            }
            
            present(popup, animated: true)
            
        }
    }
    
    @IBAction func showAddMenu() {
        if(MainViewController.isSettingsEnabled){
            hideSettings()
        }
        showMediaPickerSheet()
        
    }
    
    @IBAction func closeAddMenu() {
        
    }
    
    @IBAction func longPressItem(_ sender: UILongPressGestureRecognizer) {
       
        if sender.state != .began {
            return
        }
        
        if let indexPath = collectionView.indexPathForItem(at: sender.location(in: collectionView)) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
            updateRemove()
            toggleMode(newMode: true)
        }
    }
    
    @IBAction func removeAssets() {
        RemoveAssetAlert.present(self, getSelectedAssets(), { [weak self] success in
            guard success else {
                return
            }
            self?.toggleMode(newMode: false)
            
            if(self?.getAllAssets().count == 1 || self?.getAllAssets().count == 0 ){
                self?.selectMediaView.isHidden = true
            }
        })
    }
    
    
    // MARK: AssetPickerDelegate
    
    var currentCollection: Collection? {
        selectedProject?.currentCollection
    }
    
    func picked() {
        performSegue(withIdentifier: Self.segueShowPreview, sender: nil)
    }
    
    
    // MARK: Observers
    
    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     
     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        uploadsReadConn?.update(mappings: uploadsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        if let changes = uploadsReadConn?.getChanges(uploadsMappings) {
            for change in changes.rowChanges {
                guard change.type == .update,
                      let indexPath = change.indexPath,
                      let upload: Upload = uploadsReadConn?.object(at: indexPath, in: uploadsMappings),
                      let assetId = upload.assetId,
                      let indexPath = assetsReadConn?.indexPath(for: assetId, in: Asset.collection, with: assetsMappings)
                else {
                    continue
                }
                
                if upload.state == .uploaded {
                    
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation { // Less flickering: no fading animation.
                            self.collectionView.reloadSections([indexPath.section])
                        }
                    }
                }
                else {
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                    }
                }
            }
            
            if changes.forceFull || !changes.rowChanges.isEmpty {
                updateManageBt()
            }
        }


        var forceFull = false
        
        if let changes = collectionsReadConn?.getChanges(collectionsMappings) {
            
            forceFull = changes.forceFull || changes.rowChanges.contains(where: { $0.type == .update && $0.finalGroup == selectedProject?.id })
        }
        
        
        if let changes = assetsReadConn?.getChanges(assetsMappings) {
            forceFull = forceFull || changes.forceFull
            || changes.sectionChanges.contains(where: { $0.type == .delete || $0.type == .insert })
            || changes.rowChanges.contains(where: {
                $0.type == .delete || $0.type == .insert || $0.type == .move || $0.type == .update
            })
        }
        
        collectionView.apply(YapDatabaseChanges(forceFull, [], [])) { [weak self] _ in
            guard let self = self else { return }
            
            let hasSelectedProject = self.selectedProject != nil
            
            if hasSelectedProject {
                self.folderAssetCountLb.text = "  \(Formatters.format(self.assetsMappings.numberOfItemsInAllGroups()))  "
                
                // Ensure collection view visibility is correct based on sections
                let currentSections = self.numberOfSections(in: self.collectionView)
                let shouldBeHidden = currentSections < 1
                
                if self.collectionView.isHidden != shouldBeHidden {
                    self.collectionView.toggle(!shouldBeHidden, animated: true)
                }
            } else {
                if !self.collectionView.isHidden {
                    DispatchQueue.main.async {
                        self.collectionView.isHidden = true
                    }
                }
            }
        }
        if #available(iOS 14.0, *) {
            updateDropdownMenu()
        } else {

        }
    }
    
    
    // MARK: Private Methods
    
    /**
     Shows/hides the upload manager button. Sets the number of currently queued items.
     */
    private func updateManageBt() {
        uploadsReadConn?.asyncRead { tx in
            _ = UploadsView.countUploading(tx)
        }
    }
    
    private func toggleMode() {
        toggleMode(newMode: !inEditMode)
    }
    
    /**
     Enables/disables edit mode. Updates all UI depending on it.
     
     - parameter newMode: The new mode to set. If the same as the current one, nothing happens.
     */
    private func toggleMode(newMode: Bool) {
        if inEditMode == newMode {
            return
        }
        
        if inEditMode && collectionView.numberOfSections > 0 {
            for i in 0 ... collectionView.numberOfSections - 1 {
                collectionView.deselectSection(i, animated: true)
            }
        }
        
        inEditMode = newMode
        if(inEditMode){
            
            selectMediaView.isHidden = !inEditMode
        }
        
        updateRemove()
    }
    
    /**
     Shows/hides the  remove button, depending on if and what is selected.
     */
    private func updateRemove() {
        removeBt.isHidden = !inEditMode || collectionView.numberOfSelectedItems < 1
    }
    
    /**
     UI update: Space icon and name.
     */
    private func updateSpace() {
        if let space = SelectedSpace.space {
            spaceFavIcon.image = getServerIcon(space: space)
            navigationItem.rightBarButtonItem = menuBarButtonItem
            hintLb.text =   NSLocalizedString(
                "Tap the button below to add a folder",
                comment: "")
            welcomeLb.text = ""
            welcomeLb.isHidden = true

        }
        else {
            spaceFavIcon.image = nil
            navigationItem.rightBarButtonItem = nil
            self.titleContainer.isHidden = true

            hintLb.text =  NSLocalizedString(
                "Tap the button below to add a server",
                comment: "")
            self.titleContainerHeight.constant = 0
            welcomeLb.isHidden = false
            welcomeLb.text = NSLocalizedString("Welcome!", comment: "")
            if (sessionManager.loadSession()?.sessionId) != nil {
                navigationItem.rightBarButtonItem = menuBarButtonItem
            }
        }

        if !container.isHidden {
        }
    }
    
    private func updateProject(project passedProject: Project? = nil) {
        let project = passedProject ?? selectedProject
        if let project = project {
            // Update filter synchronously to avoid race conditions
            AbcFilteredByProjectView.updateFilter(project.id)

            // Update mappings synchronously first to ensure they're ready
            assetsReadConn?.update(mappings: assetsMappings)
            collectionsReadConn?.update(mappings: collectionsMappings)

            // Update mappings and reload collection view after filter change
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Skip if user switched to a different project (allow when selectedProject is nil, e.g. new folder not yet in list)
                if let current = self.selectedProject, current.id != project.id { return }

                // Update mappings again after filter change (in case they changed)
                self.assetsReadConn?.update(mappings: self.assetsMappings)
                self.collectionsReadConn?.update(mappings: self.collectionsMappings)

                // Always force full reload to ensure media loads (especially on project changes)
                self.collectionView.apply(YapDatabaseChanges(true, [], [])) { countChanged in
                    self.folderAssetCountLb.text = "  \(Formatters.format(self.assetsMappings.numberOfItemsInAllGroups()))  "
                    
                    // Ensure collection view visibility is correct based on sections
                    let shouldBeHidden = self.numberOfSections(in: self.collectionView) < 1
                    
                    if self.collectionView.isHidden != shouldBeHidden {
                        self.collectionView.toggle(!shouldBeHidden, animated: true)
                    }
                }
            }

            hintLb.text =  NSLocalizedString(
                "Tap the button below to add media",
                comment: "")
            folderNameLb.text = project.name
            folderNameText.text = project.name
            if(!MainViewController.isSettingsEnabled){
                self.titleContainer.isHidden = false
                self.titleContainerHeight.constant = 44
                toggleVisibility(ishidden: false)
            }
            else{
                self.titleContainer.isHidden = true
                self.titleContainerHeight.constant = 0
            }
        }
        else{
            folderNameLb.text = nil
            folderNameText.text = nil
            if SelectedSpace.space != nil {
                hintLb.text = NSLocalizedString(
                    "Tap the button below to add a folder",
                    comment: "")
                welcomeLb.text = ""
                welcomeLb.isHidden = true
            }
            DispatchQueue.main.async {
                self.collectionView.isHidden = true
            }
            if(!MainViewController.isSettingsEnabled){
                self.titleContainer.isHidden = false
                self.titleContainerHeight.constant = 44
                toggleVisibility(ishidden: true)
            }
        }
    }
    func toggleVisibility(ishidden:Bool) {

        editButton.isHidden = ishidden
        folderIndicator.isHidden = ishidden
        folderNameLb.isHidden = ishidden
        folderAssetCountLb.isHidden = ishidden
    }

    private func getSelectedAssets() -> [Asset] {
        assetsReadConn?.objects(at: collectionView.indexPathsForSelectedItems, in: assetsMappings) ?? []
    }
    private func getAllAssets()-> [Asset] {
        assetsReadConn?.objects(at: collectionView.indexPathsForVisibleItems, in: assetsMappings) ?? []
    }
    private func toggleMenu(_ toggle: Bool, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        guard menu.isHidden != !toggle else {
            completion?(true)
            return
        }

        // Ensure hosting controller is initialized
        _ = sideMenuHostingController

        if toggle {
            let hasSession = sessionManager.loadSession()?.sessionId != nil
              let hasSelectedSpace = SelectedSpace.space != nil
              
            if hasSession || hasSelectedSpace {
                menu.isHidden = false
                homeViewModel.animateMenu(show: toggle) {
                    completion?(true)
                }
            } else {
                addSpace()
            }
        }
        else {
            homeViewModel.animateMenu(show: toggle) {
                self.menu.isHidden = true
                completion?(true)
            }
        }
    }
    func pushPrivateServerSetting(space:Space) {
        privateServer = space
        performSegue(withIdentifier: MainViewController.segueShowPrivateServerSetting, sender: self)
    }
    func manageStoracha() {
        toggleMenu(false) { [weak self] _ in
            self?.navigationController?.pushViewController(StorachaSettingViewController(),animated: true)
        }
    }
}

private struct SideMenuRootView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    let coordinator: NavigationCoordinator

    var body: some View {
        SideMenuView()
            .environmentObject(homeViewModel)
            .environmentObject(coordinator)
    }
}


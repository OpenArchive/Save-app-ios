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
    
    @IBOutlet weak var EditButtonTrailingContraint: NSLayoutConstraint!
    @IBOutlet weak var titleContainerHeight: NSLayoutConstraint!
    @IBOutlet weak var titleContainer: UIView!
    private static let segueConnectSpace = "connectSpaceSegue"
    private static let segueShowPreview = "showPreviewSegue"
    private static let segueShowPrivateServerSetting = "showPrivateServerSetting"
    private static var isSettingsEnabled = false
    lazy var privateServer:Space? = nil
    private var isLongPressTapped: Bool = false
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
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "menu_icon"), for: .normal)
        button.tintColor = .black
        button.accessibilityIdentifier = "btMenu"
        button.addTarget(self, action: #selector(didTapMenuButton), for: .touchUpInside)
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
            // iOS 17 fix: Is ignored, when only set in storyboard.
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
    
    @IBOutlet weak var addMenuLb: UILabel! {
        didSet {
            addMenuLb.text = NSLocalizedString("Add media using:", comment: "")
        }
    }
    
    @IBOutlet weak var addPhotosBt: UIButton! {
        didSet {
            addPhotosBt.setTitle(NSLocalizedString("Photo Gallery", comment: ""))
        }
    }
    
    @IBOutlet weak var addFilesBt: UIButton! {
        didSet {
            addFilesBt.setTitle(NSLocalizedString("Files", comment: ""))
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
    
    @IBOutlet weak var addMenu: UIView! {
        didSet {
            addMenu.hide()
        }
    }
    @IBAction func closeMedia(_ sender: Any) {
        selectMediaView.isHidden = true
        self.toggleMode(newMode: false)
    }
    
    var selectedProject: Project? {
        get {
            sideMenu.selectedProject
        }
        set {
            sideMenu.selectedProject = newValue
        }
    }
    
    private lazy var uploadsReadConn = Db.newLongLivedReadConn()
    
    private lazy var uploadsMappings = YapDatabaseViewMappings(
        groups: UploadsView.groups, view: UploadsView.name)
    
    private lazy var projectsReadConn = Db.newLongLivedReadConn()
    
    private lazy var projectsMappings = YapDatabaseViewMappings(
        groups: ActiveProjectsView.groups, view: ActiveProjectsView.name)
    
    private lazy var collectionsReadConn = Db.newLongLivedReadConn()
    
    private lazy var collectionsMappings = CollectionsView.createMappings()
    
    private lazy var assetsReadConn = Db.newLongLivedReadConn()
    
    private lazy var assetsMappings = AbcFilteredByProjectView.createMappings()
    
    private var inEditMode = false
    
    
    private lazy var sideMenu: SideMenuViewController = {
        let vc = SideMenuViewController()
        vc.delegate = self
        vc.projectsConn = projectsReadConn
        vc.projectsMappings = projectsMappings
        
        addChild(vc)
        menu.addSubview(vc.view)
        
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.leadingAnchor.constraint(equalTo: menu.leadingAnchor).isActive = true
        vc.view.topAnchor.constraint(equalTo: menu.topAnchor).isActive = true
        vc.view.trailingAnchor.constraint(equalTo: menu.trailingAnchor).isActive = true
        vc.view.bottomAnchor.constraint(equalTo: menu.bottomAnchor).isActive = true
        
        vc.didMove(toParent: self)
        
        return vc
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
        projectsReadConn?.update(mappings: projectsMappings)
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
                        title: NSLocalizedString("Error!", comment: ""),
                        message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                        primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                        primaryButtonAction: {
                            
                        }, showCheckbox: false, iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                        iconTint:.gray
                    )
                    self.present(alertVC, animated: true)
                    
                }else{
                    selectedProject?.name = folderNameText.text
                    Db.writeConn?.setObject(currentProject)
                    renameView.isHidden = true
                    updateProject()
                }
            }}
        else{
            let alertVC = CustomAlertViewController(
                title: NSLocalizedString("Error!", comment: ""),
                message: NSLocalizedString("Folder name cannot be empty", comment: ""),
                primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                primaryButtonAction: {
                    
                }, showCheckbox: false, iconImage: Image(systemName: "exclamationmark.triangle.fill"),
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
                
            }
        }
        
        let removeAction = UIAction(title: NSLocalizedString("Remove folder from app", comment: ""), image: nil) { _ in
            
            if let project = self.selectedProject{
                RemoveProjectAlert.present(self, project, { [weak self] success in
                    guard success else {
                        return
                    }
                    
                })
                
            }
            
        }
        
        return UIMenu(title: "", children: [renameAction, selectMediaAction, archiveAction, removeAction])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        uploadsReadConn?.update(mappings: uploadsMappings)
        projectsReadConn?.update(mappings: projectsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)
        configureNavigationBar()
        updateSpace()
        updateProject()
        isLongPressTapped = false
        if #available(iOS 14.0, *) {
            editButton.menu = createDropdownMenu()
            editButton.showsMenuAsPrimaryAction = true
        }
        collectionView.toggle(numberOfSections(in: collectionView) != 0, animated: animated)
        if(MainViewController.isSettingsEnabled){
            self.titleContainer.isHidden = true
            self.titleContainerHeight.constant = 0
        }
        if inEditMode && collectionView.numberOfSelectedItems < 1 {
            toggleMode()
        }
        updateManageBt()
    
    }
    @available(iOS 14.0, *)
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
            sideMenu.reload()
        }
        
        toggleMenu(menu.isHidden)
    }
    private func configureNavigationBarLogo() {
        guard let logoImage = UIImage(named: "savelogo_w") else { return }
        
        let logoImageView = UIImageView(image: logoImage)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let logoContainer = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 40))
        logoContainer.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
            logoImageView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        let logoItem = UIBarButtonItem(customView: logoContainer)
        navigationItem.leftBarButtonItem = logoItem
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == Self.segueConnectSpace,
           let navC = segue.destination as? UINavigationController,
           let vc = navC.viewControllers.first as? SpaceWizardViewController
        {
            vc.delegate = self
        }
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
        
        // Fixed bug: YapDatabase caches these objects, therefore we need to clear
        // before we repopulate.
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
                
//                switch upload.state {
//                case .paused:
//                    NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
//                case .pending, .uploading:
//                    performSegue(withIdentifier: "editAssetsSegue", sender: indexPath.row)
//                    
//                    //      NotificationCenter.default.post(name: .uploadManagerPause, object: upload.id)
//                default:
//                    break
//                }
                
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
        toggleMenu(false)
        
        if AbcFilteredByProjectView.projectId != project?.id {
            toggleMode(newMode: false)
        }
        
        updateProject()
    }
    
    func addSpace() {
        toggleMenu(false) { [weak self] _ in
            self?.performSegue(withIdentifier: Self.segueConnectSpace, sender: self)
        }
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
        }
    }
    
    @IBAction func toggleMenu() {
        if menu.isHidden {
            sideMenu.reload()
        }
        
        toggleMenu(menu.isHidden)
    }
    
    @IBAction func addFolder() {
        toggleMode(newMode: false)
        
        toggleMenu(false) { _ in
            if SelectedSpace.available {
                if(SelectedSpace.space is  IaSpace){
                    self.navigationController?.pushViewController(AddNewFolderViewController(), animated: true)
                }
                else{
                    self.navigationController?.pushViewController(AppAddFolderViewController(), animated: true)
                }
                
            }
            else {
                self.performSegue(withIdentifier: Self.segueConnectSpace, sender: self)
            }
        }
    }
    
    @IBAction func add() {
        closeAddMenu()
        
        // Don't allow to add assets without a space or a project.
        if selectedProject == nil {
            return  self.addFolder()
        }
        
        AddInfoAlert.presentIfNeeded(viewController: self)
        
        assetPicker.pickMedia()
    }
    
    func showMediaPickerSheet() {
        
        if selectedProject == nil {
            if(!isLongPressTapped){
                isLongPressTapped.toggle()
                return addFolder()
            }
        }
        else{
            if #available(iOS 15.0, *) {
                let popup = MediaPopupViewController()
                popup.modalPresentationStyle = .overCurrentContext
                popup.modalTransitionStyle = .crossDissolve
                
                popup.onCameraTap = { [weak self] in
                    self?.assetPicker.openCamera()
                }
                popup.onGalleryTap = { [weak self] in
                    self?.assetPicker.pickMedia()
                }
                popup.onFilesTap = { [weak self] in
                    
                    self?.assetPicker.pickDocuments()
                }
                
                present(popup, animated: true)
            }
            else{
                addMenu.show2(animated: true)
            }
      }
    }

    @IBAction func showAddMenu() {
        showMediaPickerSheet()
       
    }
    
    @IBAction func closeAddMenu() {
        addMenu.hide(animated: true)
    }
    
    /**
     Deactivated, was deemed too confusing.
     */
    @IBAction func addDocument() {
        closeAddMenu()
        
        // Don't allow to add assets without a space or a project.
        if selectedProject == nil {
            return addFolder()
        }
        
        assetPicker.pickDocuments()
    }
    
    @IBAction func longPressItem(_ sender: UILongPressGestureRecognizer) {
        
        if sender.state != .began {
            return
        }
        
        if let indexPath = collectionView.indexPathForItem(at: sender.location(in: collectionView)) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
            
            toggleMode(newMode: true)
        }
    }
    
    @IBAction func removeAssets() {
        RemoveAssetAlert.present(self, getSelectedAssets(), { [weak self] success in
            guard success else {
                return
            }
            
            self?.toggleMode(newMode: false)
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
                    // Make sure, section header is reloaded, when an upload is finished.
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation { // Less flickering: no fading animation.
                            self.collectionView.reloadSections([indexPath.section])
                        }
                    }
                }
                else {
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation { // Less flickering: no fading animation.
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                    }
                }
            }
            
            if changes.forceFull || !changes.rowChanges.isEmpty {
                updateManageBt()
            }
        }
        
        if projectsReadConn?.hasChanges(projectsMappings) ?? false {
          
            updateSpace()
            sideMenu.reload()
            updateProject()
        }
        
        var forceFull = false
        
        if let changes = collectionsReadConn?.getChanges(collectionsMappings) {
            // We need to recognize changes in `Collection` objects used in the
            // section headers.
            forceFull = changes.forceFull || changes.rowChanges.contains(where: { $0.type == .update && $0.finalGroup == selectedProject?.id })
        }
        
        // Always, always, always force a full reload if anything changed.
        // No optimizing helps. Tried this again, and got crash reports again when people
        // tried to delete a folder. Forget it.
        if let changes = assetsReadConn?.getChanges(assetsMappings) {
            forceFull = forceFull || changes.forceFull
            || changes.sectionChanges.contains(where: { $0.type == .delete || $0.type == .insert })
            || changes.rowChanges.contains(where: {
                $0.type == .delete || $0.type == .insert || $0.type == .move || $0.type == .update
            })
        }
        
        collectionView.apply(YapDatabaseChanges(forceFull, [], [])) { [weak self] countChanged in
            
            guard let self = self, countChanged else {
                return
            }
            if self.selectedProject != nil {
                self.folderAssetCountLb.text = "  \(Formatters.format(self.assetsMappings.numberOfItemsInAllGroups()))  "
            }
            if self.selectedProject == nil {
                self.collectionView.isHidden = true
            }
            else{
                if self.collectionView.isHidden != (self.numberOfSections(in: self.collectionView) < 1) {
                    print(self.numberOfSections(in: self.collectionView))
                    self.collectionView.toggle(self.collectionView.isHidden, animated: true)
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
        uploadsReadConn?.asyncRead { [weak self] tx in
            let count = UploadsView.countUploading(tx)
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
            spaceFavIcon.image = space.favIcon
            sideMenu.space = space
            navigationItem.rightBarButtonItem = menuBarButtonItem
            hintLb.text =   NSLocalizedString(
                "Tap the button below to add a folder",
                comment: "")
            welcomeLb.text = ""
            welcomeLb.isHidden = true
            
        }
        else {
            spaceFavIcon.image = nil
            sideMenu.space = nil
            self.titleContainer.isHidden = true
            
           
            hintLb.text =  NSLocalizedString(
                "Tap the button below to add a server",
                comment: "")
            self.titleContainerHeight.constant = 0
            welcomeLb.isHidden = false
            welcomeLb.text = NSLocalizedString("Welcome!", comment: "")
        }
        
        if !container.isHidden {
            //  settingsVc.reload()
        }
    }
    
    private func updateProject() {
       
        if let project = selectedProject{
            
            AbcFilteredByProjectView.updateFilter(project.id)
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
            self.titleContainer.isHidden = false
            self.titleContainerHeight.constant = 44
            toggleVisibility(ishidden: true)
            DispatchQueue.main.async {
                self.collectionView.isHidden = true
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
    
    private func toggleMenu(_ toggle: Bool, _ completion: ((_ finished: Bool) -> Void)? = nil) {
        guard menu.isHidden != !toggle else {
            completion?(true)
            return
        }
        
        if toggle {
            if !SelectedSpace.available {
                addSpace()
            }
            else {
                menu.isHidden = false
                
                sideMenu.animate(toggle, completion)
            }
        }
        else {
            sideMenu.animate(toggle) { finished in
                self.menu.isHidden = true
                
                completion?(finished)
            }
        }
    }
    func pushPrivateServerSetting(space:Space) {
        privateServer = space
        performSegue(withIdentifier: MainViewController.segueShowPrivateServerSetting, sender: self)
    }
}


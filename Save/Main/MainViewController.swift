//
//  MainViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class MainViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource,
                          UINavigationControllerDelegate, SideMenuDelegate,
                          AssetPickerDelegate
{

    private static let segueConnectSpace = "connectSpaceSegue"
    private static let segueShowPreview = "showPreviewSegue"

    @IBOutlet weak var logo: UIImageView!

    @IBOutlet weak var removeBt: UIButton! {
        didSet {
            removeBt.isHidden = true
        }
    }

    @IBOutlet weak var menuBt: UIButton! {
        didSet {
            menuBt.accessibilityIdentifier = "btMenu"
        }
    }

    @IBOutlet weak var menu: UIView! {
        didSet {
            menu.isHidden = true
        }
    }

    @IBOutlet weak var spaceFavIcon: UIImageView!
    @IBOutlet weak var folderNameLb: UILabel!
    @IBOutlet weak var folderAssetCountLb: UILabel!
    @IBOutlet weak var manageBt: UIButton! {
        didSet {
            manageBt.setTitle(NSLocalizedString("Edit", comment: ""))
            manageBt.accessibilityIdentifier = "btManageUploads"
        }
    }

    @IBOutlet weak var welcomeLb: UILabel! {
        didSet {
            welcomeLb.font = welcomeLb.font.bold()
            welcomeLb.text = NSLocalizedString("Welcome!", comment: "")
        }
    }

    @IBOutlet weak var hintLb: UILabel! {
        didSet {
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
                attributes: [.font: UIFont.preferredFont(forTextStyle: .caption1)]))
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
                attributes: [.font: UIFont.preferredFont(forTextStyle: .caption1)]))
            settingsBt.accessibilityIdentifier = "btSettings"
        }
    }

    @IBOutlet weak var addMenu: UIView! {
        didSet {
            addMenu.hide()
        }
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

    private lazy var settingsVc: SettingsViewController = {
        let vc = UIStoryboard.main.instantiate(SettingsViewController.self)

        return vc
    }()

    private lazy var assetPicker = AssetPicker(self)


    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.allowsMultipleSelection = true

        uploadsReadConn?.update(mappings: uploadsMappings)
        projectsReadConn?.update(mappings: projectsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // This needs to be re-done on appear, otherwise a first-run bug will happen:
        // This class will be initialized on the first run, then the onboarding scenes
        // happen, while this class is removed. Then it will reappear.
        // If we don't do this here again, the DB state will be out of sync,
        // after the user added a server.
        // Then this scene will not show the collection, after images are added.
        // No idea, why exactly, but this is what fixes it.
        uploadsReadConn?.update(mappings: uploadsMappings)
        projectsReadConn?.update(mappings: projectsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        navigationController?.setNavigationBarHidden(true, animated: animated)

        updateSpace()
        updateProject()

        collectionView.toggle(numberOfSections(in: collectionView) != 0, animated: animated)

        // When we add while in edit mode, the edit mode is still on, but nothing is selected.
        // Fix this situation.
        if inEditMode && collectionView.numberOfSelectedItems < 1 {
            toggleMode()
        }

        updateManageBt()
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

        cell.asset = assetsReadConn?.object(at: indexPath, in: assetsMappings)

        if !(cell.asset?.isUploaded ?? true) {
            cell.upload = uploadsReadConn?.find(where: { $0.assetId == cell.asset?.id })
            cell.viewController = self
        }

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

                switch upload.state {
                case .startDownload:
                    NotificationCenter.default.post(name: .uploadManagerUnpause, object: upload.id)
                case .pending, .downloading:
                    NotificationCenter.default.post(name: .uploadManagerPause, object: upload.id)
                default:
                    break
                }

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

            self.container.show2(animated: true)
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
                let vc = UINavigationController(rootViewController: AppAddFolderViewController())
                vc.modalPresentationStyle = .popover
                vc.popoverPresentationController?.sourceView = self.menuBt
                vc.popoverPresentationController?.sourceRect = self.menuBt.bounds

                self.present(vc, animated: true)
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
            return FolderInfoAlert.presentIfNeeded(self) { [weak self] in
                self?.addFolder()
            }
        }

        assetPicker.pickMedia()
    }

    @IBAction func showAddMenu() {
        addMenu.show2(animated: true)
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

        // We only recognize this the first time, it is triggered.
        // It will continue triggering with .changed and .ended states, but
        // .ended is only released after the user lifts the finger which feels
        // awkward.
        if sender.state != .began {
            return
        }

        if let indexPath = collectionView.indexPathForItem(at: sender.location(in: collectionView)) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)

            toggleMode(newMode: true)
        }
    }

    @IBAction func removeAssets() {
        present(RemoveAssetAlert(getSelectedAssets(), { [weak self] success in
            guard success else {
                return
            }

            self?.toggleMode(newMode: false)
        }), animated: true)
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

                DispatchQueue.main.async {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }

            if changes.forceFull || !changes.rowChanges.isEmpty {
                updateManageBt()
            }
        }

        if projectsReadConn?.hasChanges(projectsMappings) ?? false {
            // Needed on iPad, where MainViewController is not reloaded,
            // because config changes happen in popovers.

            updateSpace()
            sideMenu.reload()
            updateProject()
        }

        var reload = false

        if let changes = collectionsReadConn?.getChanges(collectionsMappings) {
            // We need to recognize changes in `Collection` objects used in the
            // section headers.
            reload = changes.forceFull || changes.rowChanges.contains(where: { $0.type == .update && $0.finalGroup == selectedProject?.id })
        }

        if let changes = assetsReadConn?.getChanges(assetsMappings) {
            reload = reload || changes.forceFull
                || changes.sectionChanges.contains(where: { $0.type == .delete || $0.type == .insert })
                || changes.rowChanges.contains(where: {
                    $0.type == .delete || $0.type == .insert || $0.type == .move || $0.type == .update
                })
        }

        if reload {
            updateAssets()
        }

        if collectionView.isHidden != (numberOfSections(in: collectionView) < 1) {
            collectionView.toggle(collectionView.isHidden, animated: true)
        }
    }


    // MARK: Private Methods

    /**
     Shows/hides the upload manager button. Sets the number of currently queued items.
     */
    private func updateManageBt() {
        uploadsReadConn?.asyncRead { [weak self] tx in
            let count = UploadsView.countUploading(tx)

            DispatchQueue.main.async {
                self?.folderAssetCountLb.toggle(count < 1, animated: true)
                self?.manageBt.toggle(count > 0, animated: true)
            }
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
        }
        else {
            spaceFavIcon.image = SelectedSpace.defaultFavIcon
            sideMenu.space = nil
        }

        if !container.isHidden {
            settingsVc.reload()
        }
    }

    private func updateProject() {
        let project = selectedProject

        AbcFilteredByProjectView.updateFilter(project?.id)

        folderNameLb.text = project?.name
    }

    private func updateAssets() {
        folderAssetCountLb.text = "  \(Formatters.format(assetsMappings.numberOfItemsInAllGroups()))  "

        collectionView.reloadData()
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
}

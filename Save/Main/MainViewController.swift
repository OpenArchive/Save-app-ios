//
//  MainViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos
import YapDatabase
import TLPhotoPicker
import DownloadButton

class MainViewController: UIViewController, UICollectionViewDelegate,
UICollectionViewDataSource, UINavigationControllerDelegate, UIDocumentPickerDelegate,
ProjectsTabBarDelegate, HeaderViewDelegate, TLPhotosPickerViewControllerDelegate,
PKDownloadButtonDelegate {

    static let segueShowMenu = "showMenuSegue"
    private static let segueShowPreview = "showPreviewSegue"
    static let segueShowDarkroom = "showDarkroomSegue"
    static let segueShowBatchEdit = "showBatchEditSegue"
    private static let segueShowManagement = "showManagmentSegue"

    @IBOutlet weak var spaceFavIcon: UIImageView!
    @IBOutlet weak var spaceName: UILabel!
    @IBOutlet weak var manageBt: PKDownloadButton! {
        didSet {
            UploadCell.style(manageBt)
            manageBt.state = .downloading
            manageBt.stopDownloadButton.stopButton.setImage(nil, for: .normal)
            manageBt.stopDownloadButton.stopButton.setTitleColor(.accent, for: .normal)
            manageBt.stopDownloadButton.stopButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
            manageBt.isHidden = true
        }
    }

    @IBOutlet weak var tabBar: ProjectsTabBar! {
        didSet {
            tabBar.connection = projectsReadConn
            tabBar.viewName = ActiveProjectsView.name
            tabBar.mappings = projectsMappings
            tabBar.projectsDelegate = self
            tabBar.load()
        }
    }

    @IBOutlet weak var hintLb: UILabel! {
        didSet {
            hintLb.font = hintLb.font.bold()
            hintLb.text = NSLocalizedString("Tap buttons below to add media to your project.", comment: "")
        }
    }

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var editAssetsBt: UIBarButtonItem!
    @IBOutlet weak var removeAssetsBt: UIBarButtonItem!

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

    lazy var pickerConf: TLPhotosPickerConfigure = {
        var conf = TLPhotosPickerConfigure()
        conf.customLocalizedTitle = ["Camera Roll": NSLocalizedString("Camera Roll", comment: "")]
        conf.tapHereToChange = NSLocalizedString("Tap here to change", comment: "")
        conf.cancelTitle = NSLocalizedString("Cancel", comment: "")
        conf.doneTitle = NSLocalizedString("Done", comment: "")
        conf.emptyMessage = NSLocalizedString("No albums", comment: "")
        conf.allowedAlbumCloudShared = true
        conf.recordingVideoQuality = .typeHigh
        conf.selectedColor = .accent

        return conf
    }()


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

        updateSpace()

        navigationController?.setNavigationBarHidden(true, animated: animated)

        AbcFilteredByProjectView.updateFilter(tabBar.selectedProject?.id)

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

        AbcFilteredByProjectView.updateFilter(tabBar.selectedProject?.id)
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(assetsMappings.numberOfItems(inSection: UInt(section)))
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Int(assetsMappings.numberOfSections())
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind
        kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: HeaderView.reuseId, for: indexPath) as! HeaderView

        let group = assetsMappings.group(forSection: UInt(indexPath.section))

        let collection = Collection.get(byId: AssetsByCollectionView.collectionId(from: group),
                                        conn: collectionsReadConn)

        // Fixed bug: YapDatabase caches these objects, therefore we need to clear
        // before we repopulate.
        collection?.assets.removeAll()

        assetsReadConn?.read { transaction in
            (transaction.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewTransaction)?
                .iterateKeysAndObjects(inGroup: group!) { collName, key, object, index, stop in
                    if let asset = object as? Asset {
                        collection?.assets.append(asset)
                    }
            }
        }

        view.section = indexPath.section
        view.collection = collection
        view.delegate = self

        let title = headerButtonTitle(indexPath.section)
        view.manageBt.setTitle(title, for: .normal)
        view.manageBt.setTitle(title, for: .highlighted)

        return view
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseId, for: indexPath) as! ImageCell

        assetsReadConn?.read() { transaction in
            cell.asset = (transaction.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.assetsMappings) as? Asset
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if inEditMode {
            updateHeaderButton()
            updateToolbar()

            return
        }

        collectionView.deselectItem(at: indexPath, animated: false)

        AbcFilteredByCollectionView.updateFilter(AssetsByCollectionView.collectionId(
            from: assetsMappings.group(forSection: UInt(indexPath.section))))

        performSegue(withIdentifier: MainViewController.segueShowDarkroom, sender: indexPath.row)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        // Switch off edit mode, when last item was deselected.
        if collectionView.numberOfSelectedItems < 1 {
            toggleMode(newMode: false)
        }
        else {
            updateHeaderButton()
            updateToolbar()
        }
    }


    // MARK: Actions

    @IBAction func connectShowSpace() {
        performSegue(withIdentifier: MainViewController.segueShowMenu, sender: self)
    }

    @IBAction func addProject() {
        toggleMode(newMode: false)

        if SelectedSpace.available {
            let vc = UINavigationController(rootViewController: AddProjectViewController())
            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.sourceView = tabBar
            vc.popoverPresentationController?.sourceRect = tabBar.frame

            present(vc, animated: true)
        }
        else {
            performSegue(withIdentifier: MainViewController.segueShowMenu, sender: self)
        }
    }



    @IBAction func add() {
        // Don't allow to add assets without a space or a project.
        if tabBar.selectedProject == nil {
            return addProject()
        }

        let tlpp = TLPhotosPickerViewController()
        tlpp.delegate = self
        tlpp.configure = pickerConf

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            present(tlpp, animated: true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization() { newStatus in
                if newStatus == .authorized {
                    DispatchQueue.main.async {
                        self.present(tlpp, animated: true)
                    }
                }
            }

        case .restricted:
            AlertHelper.present(
                self, message: NSLocalizedString("Sorry, you are not allowed to view the camera roll.", comment: ""),
                title: NSLocalizedString("Access Restricted", comment: ""),
                actions: [AlertHelper.cancelAction()])

        case .denied:
            showMissingPermissionAlert()

        @unknown default:
            break
        }
    }

    /**
     Deactivated, was deemed too confusing.
     */
    @IBAction func addDocument() {
        // Don't allow to add assets without a space or a project.
        if tabBar.selectedProject == nil {
            return addProject()
        }

        let vc = UIDocumentPickerViewController(documentTypes: [kUTTypeItem as String], in: .import)
        vc.delegate = self

        present(vc, animated: true)
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

    @IBAction func editAssets() {
        let count = collectionView.numberOfSelectedItems

        if count == 1 {
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                toggleMode()

                // Trigger selection, so DarkroomViewController gets pushed.
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
                collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
        else if count > 1 {
            performSegue(withIdentifier: MainViewController.segueShowBatchEdit, sender: getSelectedAssets())
        }
    }

    @IBAction func removeAssets() {
        present(RemoveAssetAlert(getSelectedAssets(), { self.toggleMode(newMode: false) }), animated: true)
    }


    // MARK: TLPhotosPickerViewControllerDelegate

    func dismissPhotoPicker(withPHAssets assets: [PHAsset]) {
        guard let collection = tabBar.selectedProject?.currentCollection,
            assets.count > 0 else {
            return
        }

        for asset in assets {
            let id = UIApplication.shared.beginBackgroundTask()

            AssetFactory.create(fromPhasset: asset, collection) { asset in
                UIApplication.shared.endBackgroundTask(id)
            }
        }

        AbcFilteredByCollectionView.updateFilter(collection.id)

        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: nil)
    }

    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        showMissingPermissionAlert(controller: picker)
    }

    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        showMissingPermissionAlert(
            controller: picker,
            NSLocalizedString(
                "Please go to the Settings app to grant this app access to your camera, if you want to upload photos or videos.",
                comment: ""))
    }


    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let collection = tabBar.selectedProject?.currentCollection,
            controller.documentPickerMode == .import &&
            urls.count > 0 else {
            return
        }

        for url in urls {
            let id = UIApplication.shared.beginBackgroundTask()

            AssetFactory.create(fromFileUrl: url, collection) { asset in
                UIApplication.shared.endBackgroundTask(id)
            }
        }

        AbcFilteredByCollectionView.updateFilter(collection.id)

        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: nil)
    }


    // MARK: ProjectsTabBarDelegate

    func didSelect(_ tabBar: ProjectsTabBar, project: Project?) {
        if AbcFilteredByProjectView.projectId != project?.id {
            toggleMode(newMode: false)
        }

        AbcFilteredByProjectView.updateFilter(project?.id)
    }


    // MARK: HeaderViewDelegate

    func showDetails(_ collection: Collection, section: Int? = nil) {

        // If in "edit" mode, select all of this section.
        if inEditMode {

            if let section = section {
                if collectionView.isSectionSelected(section) {
                    // If all are selected, deselect again.
                    collectionView.deselectSection(section, animated: false)
                }
                else {
                    collectionView.selectSection(section, animated: false, scrollPosition: .centeredVertically)
                }

                // Switch off edit mode, when last item was deselected.
                if collectionView.numberOfSelectedItems < 1 {
                    toggleMode(newMode: false)
                }
                else {
                    updateHeaderButton()
                    updateToolbar()
                }
            }

            return
        }

        // If not in edit mode, go to PreviewViewController.
        AbcFilteredByCollectionView.updateFilter(collection.id)

        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: nil)
    }


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton, currentState state: PKDownloadButtonState) {
        performSegue(withIdentifier: MainViewController.segueShowManagement, sender: nil)
    }


    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DarkroomViewController,
            let index = sender as? Int {

            vc.selected = index
        }
        else if segue.identifier == MainViewController.segueShowMenu {
            segue.destination.popoverPresentationController?.sourceView = spaceFavIcon
            segue.destination.popoverPresentationController?.sourceRect = spaceFavIcon.bounds
        }
        else if let vc = segue.destination as? BatchEditViewController {
            vc.assets = sender as? [Asset]
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if let notifications = uploadsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = uploadsReadConn?.ext(UploadsView.name) as? YapDatabaseViewConnection
        {
            uploadsReadConn?.update(mappings: uploadsMappings)

            if viewConn.hasChanges(for: notifications) {
                updateManageBt()
            }
        }

        if let notifications = projectsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = projectsReadConn?.ext(ActiveProjectsView.name) as? YapDatabaseViewConnection
        {
            // Fix crash by checking, if the snapshots are in sync.
            if projectsMappings.isNextSnapshot(notifications)
            {
                if viewConn.hasChanges(for: notifications) {
                    updateSpace() // Needed on iPad, where MainViewController is not reloaded,
                    // because config changes happen in popovers.

                    let (_, rowChanges) = viewConn.getChanges(forNotifications: notifications,
                                                              withMappings: projectsMappings)

                    for change in rowChanges {
                        tabBar.handle(change)
                    }

                    AbcFilteredByProjectView.updateFilter(tabBar.selectedProject?.id)
                }
            }
            else {
                updateSpace()
                projectsReadConn?.update(mappings: projectsMappings)
                tabBar.load()

                AbcFilteredByProjectView.updateFilter(tabBar.selectedProject?.id)
            }
        }

        var reload = false

        if let notifications = collectionsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = collectionsReadConn?.ext(CollectionsView.name) as? YapDatabaseViewConnection
        {
            if collectionsMappings.isNextSnapshot(notifications)
            {
                if viewConn.hasChanges(for: notifications)
                {
                    let (_, collectionChanges) = viewConn.getChanges(forNotifications: notifications,
                                                                     withMappings: collectionsMappings)

                    // We need to recognize changes in `Collection` objects used in the
                    // section headers.
                    reload = collectionChanges.contains { $0.type == .update && $0.finalGroup == tabBar.selectedProject?.id }
                }
            }
            else {
                reload = true
            }
        }

        collectionsReadConn?.update(mappings: collectionsMappings)

        if !reload {
            if let notifications = assetsReadConn?.beginLongLivedReadTransaction(),
                let viewConn = assetsReadConn?.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewConnection {

                if assetsMappings.isNextSnapshot(notifications)
                {
                    if viewConn.hasChanges(for: notifications)
                    {
                        let (sectionChanges, rowChanges) = viewConn.getChanges(forNotifications: notifications,
                                                                               withMappings: assetsMappings)

                        reload = sectionChanges.contains(where: { $0.type == .delete || $0.type == .insert })

                        if !reload {
                            reload = rowChanges.contains(where: {
                                $0.type == .delete || $0.type == .insert || $0.type == .move || $0.type == .update
                            })
                        }
                    }
                }
                else {
                    reload = true
                }
            }
        }

        assetsReadConn?.update(mappings: assetsMappings)

        if reload {
            collectionView.reloadData()
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
        uploadsReadConn?.asyncRead { [weak self] transaction in
            let count = UploadsView.countUploading(transaction)

            DispatchQueue.main.async {
                if count > 0 {
                    self?.manageBt.stopDownloadButton.stopButton.setTitle(Formatters.format(count), for: .normal)
                    self?.manageBt.show2(animated: true)
                }
                else {
                    self?.manageBt.hide(animated: true)
                }
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

        updateHeaderButton()
        updateToolbar()
    }

    /**
     Enables/disables the edit and remove buttons, depending on if and what is selected.
     */
    private func updateToolbar() {
        var editEnabled = false
        var removeEnabled = false

        if inEditMode && collectionView.numberOfSelectedItems > 0 {
            editEnabled = true
            removeEnabled = true

            for asset in getSelectedAssets(preheat: true) {
                if asset.collection?.closed != nil {
                    editEnabled = false
                    break
                }
            }
        }

        editAssetsBt.isEnabled = editEnabled
        removeAssetsBt.isEnabled = removeEnabled
    }

    /**
     UI update: Space icon and name.
    */
    private func updateSpace() {
        if let space = SelectedSpace.space {
            spaceFavIcon.image = space.favIcon
            spaceName.text = space.prettyName
        }
        else {
            spaceFavIcon.image = SelectedSpace.defaultFavIcon
            spaceName.text = Bundle.main.displayName
        }
    }

    private func updateHeaderButton() {
        for i in 0 ... collectionView.numberOfSections {
            if let header = collectionView.supplementaryView(
                forElementKind: "UICollectionElementKindSectionHeader",
                at: IndexPath(item: 0, section: i)) as? HeaderView {

                let title = headerButtonTitle(i)

                header.manageBt.setTitle(title, for: .normal)
                header.manageBt.setTitle(title, for: .highlighted)
            }
        }
    }

    private func headerButtonTitle(_ section: Int) -> String {
        return inEditMode
            ? (collectionView.isSectionSelected(section)
               ? NSLocalizedString("Deselect", comment: "")
               : NSLocalizedString("Select", comment: ""))
            : NSLocalizedString("Next", comment: "")
    }

    private func getSelectedAssets(preheat: Bool = false) -> [Asset] {
        var assets = [Asset]()

        assetsReadConn?.read() { transaction in
            for indexPath in self.collectionView.indexPathsForSelectedItems ?? [] {
                if let asset = (transaction.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewTransaction)?
                    .object(at: indexPath, with: self.assetsMappings) as? Asset
                {
                    if preheat,
                        let collectionId = asset.collectionId,
                        let collection = transaction.object(forKey: collectionId, inCollection: Collection.collection) as? Collection
                    {
                        asset.collection = collection
                    }

                    assets.append(asset)
                }
            }
        }

        return assets
    }

    private func showMissingPermissionAlert(controller: UIViewController? = nil, _ message: String? = nil) {
        var actions = [AlertHelper.cancelAction()]

        if let url = URL(string: UIApplication.openSettingsURLString) {
            actions.append(AlertHelper.defaultAction(NSLocalizedString("Settings", comment: ""), handler: { _ in
                UIApplication.shared.open(url)
            }))
        }

        AlertHelper.present(
            controller ?? self,
            message: message ?? NSLocalizedString(
                "Please go to the Settings app to grant this app access to your photo library, if you want to upload photos or videos.",
                comment: ""),
            title: NSLocalizedString("Access Denied", comment: ""),
            actions: actions)
    }
}

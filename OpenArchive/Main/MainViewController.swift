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
import MaterialComponents.MaterialTabs
import TLPhotoPicker
import DownloadButton

class MainViewController: UIViewController, UICollectionViewDelegate,
UICollectionViewDataSource, UINavigationControllerDelegate,
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
            manageBt.stopDownloadButton.stopButton.setTitleColor(UIColor.accent, for: .normal)
            manageBt.stopDownloadButton.stopButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
            manageBt.isHidden = true
        }
    }

    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var selectBt: UIBarButtonItem!
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

    lazy var tabBar: ProjectsTabBar = {
        let tabBar = ProjectsTabBar(frame: tabBarContainer.bounds, projectsReadConn,
                                    viewName: ActiveProjectsView.name, projectsMappings)

        tabBar.projectsDelegate = self

        return tabBar
    }()

    lazy var pickerConf: TLPhotosPickerConfigure = {
        var conf = TLPhotosPickerConfigure()
        conf.customLoclizedTitle = ["Camera Roll": "Camera Roll".localize()]
        conf.tapHereToChange = "Tap here to change".localize()
        conf.cancelTitle = "Cancel".localize()
        conf.doneTitle = "Done".localize()
        conf.emptyMessage = "No albums".localize()
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

        tabBar.addToSubview(tabBarContainer)

        Db.add(observer: self, #selector(yapDatabaseModified))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
        // Reset collection, otherwise an inconsistent changeset will be applied
        // in #yapDatabaseModified.
        collectionView.reloadData()

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
                .enumerateKeysAndObjects(inGroup: group!) { collName, key, object, index, stop in
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
        updateHeaderButton()
        updateToolbar()
    }


    // MARK: Actions

    @IBAction func connectShowSpace() {
        performSegue(withIdentifier: MainViewController.segueShowMenu, sender: self)
    }

    @IBAction func add() {
        // Don't allow to add assets without a space or a project.
        if tabBar.selectedProject == nil {
            return didSelectAdd(tabBar)
        }

        let tlpp = TLPhotosPickerViewController()
        tlpp.delegate = self
        tlpp.configure = pickerConf

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
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
                self, message: "Sorry, you are not allowed to view the camera roll.".localize(),
                title: "Access Restricted".localize(),
                actions: [AlertHelper.cancelAction()])

        case .denied:
            AlertHelper.present(
                self,
                message: "Please go to the Settings app to grant this app access to your photo library, if you want to upload photos or videos.".localize(),
                title: "Access Denied".localize(),
                actions: [AlertHelper.cancelAction()])
        @unknown default:
            break
        }
    }

    @IBAction func toggleMode() {
        toggleMode(newMode: !inEditMode)
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
            AssetFactory.create(fromPhasset: asset, collection)
        }

        AbcFilteredByCollectionView.updateFilter(collection.id)

        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: nil)
    }


    // MARK: ProjectsTabBarDelegate

    func didSelectAdd(_ tabBar: ProjectsTabBar) {
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

    func didSelect(_ tabBar: ProjectsTabBar, project: Project) {
        if AbcFilteredByProjectView.projectId != project.id {
            toggleMode(newMode: false)
        }

        AbcFilteredByProjectView.updateFilter(project.id)
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

                updateHeaderButton()
                updateToolbar()
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
            let viewConn = uploadsReadConn?.ext(UploadsView.name) as? YapDatabaseViewConnection {

            uploadsReadConn?.update(mappings: uploadsMappings)

            if viewConn.hasChanges(for: notifications) {
                updateManageBt()
            }
        }

        if let notifications = projectsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = projectsReadConn?.ext(ActiveProjectsView.name) as? YapDatabaseViewConnection {

            if viewConn.hasChanges(for: notifications) {
                updateSpace() // Needed on iPad, where MainViewController is not reloaded,
                // because config changes happen in popovers.

                var rowChanges = NSArray()

                viewConn.getSectionChanges(nil, rowChanges: &rowChanges,
                                           for: notifications, with: projectsMappings)

                for change in rowChanges as? [YapDatabaseViewRowChange] ?? [] {
                    tabBar.handle(change)
                }
            }
            else {
                projectsReadConn?.update(mappings: projectsMappings)
            }
        }

        var toDelete = IndexSet()
        var toInsert = IndexSet()
        var toReload = IndexSet()

        if let notifications = collectionsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = collectionsReadConn?.ext(CollectionsView.name) as? YapDatabaseViewConnection {

            if viewConn.hasChanges(for: notifications) {
                var collectionChanges = NSArray()

                viewConn.getSectionChanges(nil, rowChanges: &collectionChanges,
                                           for: notifications,
                                           with: collectionsMappings)

                // We need to recognize changes in `Collection` objects used in the
                // section headers.
                for change in collectionChanges as? [YapDatabaseViewRowChange] ?? [] {
                    switch change.type {
                    case .update:
                        if let indexPath = change.indexPath,
                            change.finalGroup == tabBar.selectedProject?.id {

                            toReload.insert(indexPath.row)
                        }
                    default:
                        break
                    }
                }
            }
            else {
                collectionsReadConn?.update(mappings: collectionsMappings)
            }
        }

        if let notifications = assetsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = assetsReadConn?.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewConnection {

            if viewConn.hasChanges(for: notifications) {
                var rowChanges = NSArray()
                var sectionChanges = NSArray()

                viewConn.getSectionChanges(&sectionChanges, rowChanges: &rowChanges,
                                           for: notifications, with: assetsMappings)

                for change in sectionChanges as? [YapDatabaseViewSectionChange] ?? [] {
                    switch change.type {
                    case .delete:
                        toDelete.insert(Int(change.index))
                    case .insert:
                        toInsert.insert(Int(change.index))
                    default:
                        break
                    }
                }

                // We need to reload the complete section, so the section header
                // gets updated, too, and the `Collection.assets` array along with it.
                for change in rowChanges as? [YapDatabaseViewRowChange] ?? [] {
                    switch change.type {
                    case .delete:
                        if let indexPath = change.indexPath {
                            toReload.insert(indexPath.section)
                        }
                    case .insert:
                        if let newIndexPath = change.newIndexPath {
                            toReload.insert(newIndexPath.section)
                        }
                    case .move:
                        if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                            toReload.insert(indexPath.section)
                            toReload.insert(newIndexPath.section)
                        }
                    case .update:
                        if let indexPath = change.indexPath {
                            toReload.insert(indexPath.section)
                        }
                    @unknown default:
                        break
                    }
                }
            }
            else {
                assetsReadConn?.update(mappings: assetsMappings)
            }
        }

        // Don't reload sections, which are about to be deleted or inserted.
        toReload.subtract(toDelete)
        toReload.subtract(toInsert)

        if toDelete.count > 0 || toInsert.count > 0 || toReload.count > 0 {
            collectionView.performBatchUpdates({
                collectionView.deleteSections(toDelete)
                collectionView.insertSections(toInsert)
                collectionView.reloadSections(toReload)
            })

            collectionView.toggle(numberOfSections(in: collectionView) != 0, animated: true)
        }
    }


    // MARK: Private Methods

    /**
     Shows/hides the upload manager button. Sets the number of currently queued items.
     */
    private func updateManageBt() {
        uploadsReadConn?.asyncRead { transaction in
            let count = (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .numberOfItems(inGroup: Upload.collection) ?? 0

            DispatchQueue.main.async {
                if count > 0 {
                    self.manageBt.stopDownloadButton.stopButton.setTitle(Formatters.format(count), for: .normal)
                    self.manageBt.show2(animated: true)
                }
                else {
                    self.manageBt.hide(animated: true)
                }
            }
        }
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

        selectBt.title = inEditMode ? "Cancel".localize() : "Select".localize()

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

            for asset in getSelectedAssets() {
                if asset.isUploaded {
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
            ? (collectionView.isSectionSelected(section) ? "Deselect".localize() : "Select".localize())
            : "Next".localize()
    }

    private func getSelectedAssets() -> [Asset] {
        var assets = [Asset]()

        assetsReadConn?.read() { transaction in
            for indexPath in self.collectionView.indexPathsForSelectedItems ?? [] {
                if let asset = (transaction.ext(AbcFilteredByProjectView.name) as? YapDatabaseViewTransaction)?
                    .object(at: indexPath, with: self.assetsMappings) as? Asset
                {
                    assets.append(asset)
                }
            }
        }

        return assets
    }
}

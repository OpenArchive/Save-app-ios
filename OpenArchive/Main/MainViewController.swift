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

    private static let segueConnectSpace = "connectSpaceSegue"
    private static let segueShowSpace = "showSpaceSegue"
    private static let segueShowPreview = "showPreviewSegue"
    private static let segueShowEdit = "showEditSegue"
    private static let segueShowManagement = "showManagmentSegue"

    @IBOutlet weak var spaceFavIcon: UIImageView!
    @IBOutlet weak var spaceName: UILabel!
    @IBOutlet weak var manageBt: PKDownloadButton! {
        didSet {
            UploadCell.style(manageBt)
            manageBt.state = .startDownload
        }
    }

    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addBt: MDCFloatingButton!

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings = YapDatabaseViewMappings(
        groups: ActiveProjectsView.groups, view: ActiveProjectsView.name)

    private lazy var collectionsReadConn = Db.newLongLivedReadConn()

    private lazy var collectionsMappings = CollectionsView.createMappings()

    private lazy var assetsReadConn = Db.newLongLivedReadConn()

    private lazy var assetsMappings = AssetsByCollectionFilteredView.createMappings()


    private lazy var tabBar: ProjectsTabBar = {
        let tabBar = ProjectsTabBar(frame: tabBarContainer.bounds, projectsReadConn,
                                    viewName: ActiveProjectsView.name, projectsMappings)

        tabBar.projectsDelegate = self

        return tabBar
    }()

    lazy var pickerConf: TLPhotosPickerConfigure = {
        var conf = TLPhotosPickerConfigure()
        conf.defaultCameraRollTitle = "Camera Roll".localize()
        conf.tapHereToChange = "Tap here to change".localize()
        conf.cancelTitle = "Cancel".localize()
        conf.doneTitle = "Done".localize()
        conf.emptyMessage = "No albums".localize()
        conf.allowedAlbumCloudShared = true
        conf.recordingVideoQuality = .typeHigh
        conf.selectedColor = UIColor.accent

        return conf
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        projectsReadConn?.update(mappings: projectsMappings)
        collectionsReadConn?.update(mappings: collectionsMappings)
        assetsReadConn?.update(mappings: assetsMappings)

        tabBar.addToSubview(tabBarContainer)

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModifiedExternally, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let space = SelectedSpace.space {
            spaceFavIcon.image = space.favIcon
            spaceName.text = space.prettyName
        }
        else {
            spaceFavIcon.image = SelectedSpace.defaultFavIcon
            spaceName.text = "SAVE".localize()
        }

        navigationController?.setNavigationBarHidden(true, animated: animated)

        AssetsByCollectionFilteredView.updateFilter(tabBar.selectedProject?.id)

        collectionView.toggle(numberOfSections(in: collectionView) != 0, animated: animated)
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
            (transaction.ext(AssetsByCollectionFilteredView.name) as? YapDatabaseViewTransaction)?
                .enumerateKeysAndObjects(inGroup: group!) { collName, key, object, index, stop in
                    if let asset = object as? Asset {
                        collection?.assets.append(asset)
                    }
            }
        }

        view.collection = collection
        view.delegate = self

        return view
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseId, for: indexPath) as! ImageCell

        assetsReadConn?.read() { transaction in
            cell.asset = (transaction.ext(AssetsByCollectionFilteredView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.assetsMappings) as? Asset
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let group = assetsMappings.group(forSection: UInt(indexPath.section))

        let collection = Collection.get(byId: AssetsByCollectionView.collectionId(from: group),
                                        conn: collectionsReadConn)


        performSegue(withIdentifier: MainViewController.segueShowEdit, sender: (collection, indexPath.row))
    }


    // MARK: Actions

    @IBAction func connectShowSpace() {
        performSegue(withIdentifier: SelectedSpace.available
            ? MainViewController.segueShowSpace
            : MainViewController.segueConnectSpace, sender: self)
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
                self, message: "Sorry, you are not allowed to view the photo library.".localize(),
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


    // MARK: TLPhotosPickerViewControllerDelegate

    func dismissPhotoPicker(withPHAssets assets: [PHAsset]) {
        guard let collection = tabBar.selectedProject?.currentCollection else {
            return
        }

        for asset in assets {
            AssetFactory.create(fromPhasset: asset, collection)
        }
    }


    // MARK: ProjectsTabBarDelegate

    func didSelectAdd(_ tabBar: ProjectsTabBar) {
        if SelectedSpace.available {
            navigationController?.pushViewController(NewProjectViewController(),
                                                     animated: true)
        }
        else {
            performSegue(withIdentifier: MainViewController.segueConnectSpace, sender: self)
        }
    }

    func didSelect(_ tabBar: ProjectsTabBar, project: Project) {
        AssetsByCollectionFilteredView.updateFilter(project.id)
    }


    // MARK: HeaderViewDelegate

    func showDetails(_ collection: Collection) {
        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: collection)
    }


    // MARK: PKDownloadButtonDelegate

    func downloadButtonTapped(_ downloadButton: PKDownloadButton, currentState state: PKDownloadButtonState) {
        performSegue(withIdentifier: MainViewController.segueShowManagement, sender: nil)
    }


    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let previewVc = segue.destination as? PreviewViewController,
            let collection = sender as? Collection {
            
            previewVc.collection = collection
        }
        else if let editVc = segue.destination as? EditViewController,
            let (collection, index) = sender as? (Collection, Int) {

            editVc.collection = collection
            editVc.selected = index
        }
    }

    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if let notifications = projectsReadConn?.beginLongLivedReadTransaction(),
            let viewConn = projectsReadConn?.ext(ActiveProjectsView.name) as? YapDatabaseViewConnection {

            if viewConn.hasChanges(for: notifications) {
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
            let viewConn = assetsReadConn?.ext(AssetsByCollectionFilteredView.name) as? YapDatabaseViewConnection {

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
}

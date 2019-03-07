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

class MainViewController: UIViewController, UICollectionViewDelegate,
UICollectionViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
ProjectsTabBarDelegate, HeaderViewDelegate {

    private static let segueConnectSpace = "connectSpaceSegue"
    private static let segueShowSpace = "showSpaceSegue"
    private static let segueShowPreview = "showPreviewSegue"
    private static let segueShowEdit = "showEditSegue"

    @IBOutlet weak var spaceFavIcon: UIImageView!
    @IBOutlet weak var spaceName: UILabel!
    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addBt: MDCFloatingButton!

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: ProjectsView.groups,
                                               view: ProjectsView.name)

        projectsReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private lazy var collectionsReadConn = Db.newLongLivedReadConn()

    private lazy var collectionsMappings: YapDatabaseViewMappings = {
        let mappings = CollectionsView.mappings

        collectionsReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private lazy var assetsReadConn = Db.newLongLivedReadConn()

    private lazy var assetsMappings: YapDatabaseViewMappings = {
        let mappings = AssetsByCollectionFilteredView.mappings

        assetsReadConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()


    private lazy var tabBar: ProjectsTabBar = {
        let tabBar = ProjectsTabBar(frame: tabBarContainer.bounds, projectsReadConn,
                                    viewName: ProjectsView.name, projectsMappings)

        tabBar.projectsDelegate = self

        return tabBar
    }()

    lazy var imagePicker: UIImagePickerController = {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
        imagePicker.modalPresentationStyle = .popover

        return imagePicker
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        tabBar.addToSubview(tabBarContainer)

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
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

        imagePicker.popoverPresentationController?.sourceView = addBt
        imagePicker.popoverPresentationController?.sourceRect = addBt.bounds

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            present(imagePicker, animated: true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization() { newStatus in
                if newStatus == .authorized {
                    self.present(self.imagePicker, animated: true)
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
        }
    }
    

    // MARK: UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo
        info: [UIImagePickerController.InfoKey : Any]) {

        if let type = info[.mediaType] as? String,
            let url = info[.referenceURL] as? URL,
            let collection = tabBar.selectedProject?.currentCollection {

            AssetFactory.create(fromAlAssetUrl: url, type, collection) { asset in
                Db.writeConn?.asyncReadWrite() { transaction in
                    transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                }
            }
        }

        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }


    // MARK: ProjectsTabBarDelegate

    func didSelectAdd(_ tabBar: ProjectsTabBar) {
        if SelectedSpace.available {
            navigationController?.pushViewController(ProjectViewController(),
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

    func showUploadManager() {
        print("[\(String(describing: type(of: self)))]#showUploadManager TODO: Go to upload manager")
    }

    func showDetails(_ collection: Collection) {
        performSegue(withIdentifier: MainViewController.segueShowPreview, sender: collection)
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
        var rowChanges = NSArray()

        (projectsReadConn?.ext(ProjectsView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(nil,
                               rowChanges: &rowChanges,
                               for: projectsReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: projectsMappings)

        for change in rowChanges as? [YapDatabaseViewRowChange] ?? [] {
            tabBar.handle(change)
        }

        var collectionChanges = NSArray()

        (collectionsReadConn?.ext(CollectionsView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(nil,
                               rowChanges: &collectionChanges,
                               for: collectionsReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: collectionsMappings)

        rowChanges = NSArray()
        var sectionChanges = NSArray()

        (assetsReadConn?.ext(AssetsByCollectionFilteredView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(&sectionChanges,
                               rowChanges: &rowChanges,
                               for: assetsReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: assetsMappings)

        if let rowChanges = rowChanges as? [YapDatabaseViewRowChange],
            let sectionChanges = sectionChanges as? [YapDatabaseViewSectionChange],
            let collectionChanges = collectionChanges as? [YapDatabaseViewRowChange],
            rowChanges.count > 0 || sectionChanges.count > 0 || collectionChanges.count > 0 {

            collectionView.performBatchUpdates({
                for change in sectionChanges {
                    switch change.type {
                    case .delete:
                        collectionView.deleteSections([IndexSet.Element(change.index)])
                    case .insert:
                        collectionView.insertSections([IndexSet.Element(change.index)])
                    default:
                        break
                    }
                }

                // We need to recognize changes in `Collection` objects used in the
                // section headers.
                for change in collectionChanges {
                    switch change.type {
                    case .update:
                        if let indexPath = change.indexPath,
                            change.finalGroup == tabBar.selectedProject?.id {

                            collectionView.reloadSections([IndexSet.Element(indexPath.row)])
                        }
                    default:
                        break
                    }
                }

                for change in rowChanges {
                    switch change.type {
                    case .delete:
                        if let indexPath = change.indexPath {
                            collectionView.deleteItems(at: [indexPath])
                        }
                    case .insert:
                        if let newIndexPath = change.newIndexPath {
                            collectionView.insertItems(at: [newIndexPath])
                        }
                    case .move:
                        if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                            collectionView.moveItem(at: indexPath, to: newIndexPath)
                        }
                    case .update:
                        if let indexPath = change.indexPath {
                            collectionView.reloadItems(at: [indexPath])
                        }
                    }
                }
            })

            collectionView.toggle(numberOfSections(in: collectionView) != 0, animated: true)
        }
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        projectsReadConn?.beginLongLivedReadTransaction()

        projectsReadConn?.read { transaction in
            self.projectsMappings.update(with: transaction)
            self.tabBar.reloadInputViews()
        }

        collectionsReadConn?.beginLongLivedReadTransaction()

        collectionsReadConn?.read { transaction in
            self.collectionsMappings.update(with: transaction)
        }

        assetsReadConn?.beginLongLivedReadTransaction()

        assetsReadConn?.read { transaction in
            self.assetsMappings.update(with: transaction)
            self.collectionView.reloadData()
        }
    }
}

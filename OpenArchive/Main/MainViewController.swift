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
MDCTabBarDelegate {

    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addBt: MDCFloatingButton!

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: ProjectsView.groups, view: ProjectsView.name)

        projectsReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private lazy var assetsReadConn = Db.newLongLivedReadConn()

    private lazy var assetsMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(
            groupFilterBlock: { group, transaction in
                return true
            },
            sortBlock: { group1, group2, transaction in
                return group1.compare(group2)
            },
            view: AssetsByCollectionFilteredView.name)

        assetsReadConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()


    private lazy var tabBar: TabBar = {
        let tabBar = TabBar(frame: tabBarContainer.bounds, projectsReadConn,
                            viewName: ProjectsView.name, projectsMappings)

        tabBar.delegate = self

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

        avatar.image = Profile.avatar ?? Profile.defaultAvatar

        navigationController?.setNavigationBarHidden(true, animated: animated)
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

        view.set(Collection.get(byId: assetsMappings.group(forSection: UInt(indexPath.section))))

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
        let vc = DetailsViewController()

        if let imageCell = collectionView.cellForItem(at: indexPath) as? ImageCell {
            vc.asset = imageCell.asset
        }

        navigationController?.pushViewController(vc, animated: true)
    }


    // MARK: Actions

    @IBAction func add() {
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


    // MARK: MDCTabBarDelegate

    func tabBar(_ tabBar: MDCTabBar, shouldSelect item: UITabBarItem) -> Bool {
        if item.tag == TabBar.addTabItemTag {
            navigationController?.pushViewController(ProjectViewController(),
                                                     animated: true)

            return false
        }

        AssetsByCollectionFilteredView.updateFilter(self.tabBar.selectedProject?.id)

        return true
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

        if let changes = rowChanges as? [YapDatabaseViewRowChange] {
            for change in changes {
                tabBar.handle(change)
            }
        }

        rowChanges = NSArray()
        var sectionChanges = NSArray()

        (assetsReadConn?.ext(AssetsByCollectionFilteredView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(&sectionChanges,
                               rowChanges: &rowChanges,
                               for: assetsReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: assetsMappings)

        if let rowChanges = rowChanges as? [YapDatabaseViewRowChange],
            let sectionChanges = sectionChanges as? [YapDatabaseViewSectionChange],
            rowChanges.count > 0 || sectionChanges.count > 0 {

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
        }
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        projectsReadConn?.beginLongLivedReadTransaction()

        projectsReadConn?.read() { transaction in
            self.projectsMappings.update(with: transaction)
            self.tabBar.reloadInputViews()
        }

        assetsReadConn?.beginLongLivedReadTransaction()

        assetsReadConn?.read() { transaction in
            self.assetsMappings.update(with: transaction)
            self.collectionView.reloadData()
        }
    }
}

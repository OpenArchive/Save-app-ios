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

    @IBOutlet weak var tabBarContainer: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addBt: MDCFloatingButton!

    private static let addTabItemTag = 666
    
    lazy var writeConn = Db.newConnection()

    lazy var readConn: YapDatabaseConnection? = {
        let conn = Db.newConnection()
        conn?.beginLongLivedReadTransaction()

        return conn
    }()

    lazy var mappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: AssetsView.groups, view: AssetsView.name)

        readConn?.read() { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()


    private lazy var tabBar: MDCTabBar = {
        let tabBar = MDCTabBar(frame: tabBarContainer.bounds)

        tabBar.items = [UITabBarItem(title: "All".localize(), image: nil, tag: 0)]

        var counter = 1

        readConn?.read() { transaction in
            transaction.enumerateKeysAndObjects(inCollection: Project.collection) {
                key, object, stop in

                if let project = object as? Project {
                    tabBar.items.append(UITabBarItem(title: project.name, image: nil, tag: counter))
                    counter += 1
                }
            }
        }

        tabBar.items.append(UITabBarItem(title: "+".localize(), image: nil, tag: MainViewController.addTabItemTag))


        tabBar.itemAppearance = .titles

        tabBar.setTitleColor(view.tintColor, for: .normal)
        tabBar.setTitleColor(UIColor.black, for: .selected)
        tabBar.bottomDividerColor = UIColor.lightGray

        tabBar.sizeToFit()

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

        tabBarContainer.addSubview(tabBar)

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModified),
                                               name: .YapDatabaseModified,
                                               object: readConn?.database)

        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                                               name: .YapDatabaseModifiedExternally,
                                               object: readConn?.database)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: 0))
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseId, for: indexPath) as! ImageCell

        readConn?.read() { transaction in
            cell.asset = (transaction.ext(AssetsView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Asset
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
            let url = info[.referenceURL] as? URL {

            AssetFactory.create(fromAlAssetUrl: url, mediaType: type) { asset in
                self.writeConn?.asyncReadWrite() { transaction in
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
        if item.tag == MainViewController.addTabItemTag {
            navigationController?.pushViewController(ProjectViewController(),
                                                     animated: true)

            return false
        }

        return true
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if let readConn = readConn {
            var changes = NSArray()

            (readConn.ext(AssetsView.name) as? YapDatabaseViewConnection)?
                .getSectionChanges(nil,
                                   rowChanges: &changes,
                                   for: readConn.beginLongLivedReadTransaction(),
                                   with: mappings)

            if let changes = changes as? [YapDatabaseViewRowChange],
                changes.count > 0 {

                collectionView.performBatchUpdates({
                    for change in changes {
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
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        readConn?.beginLongLivedReadTransaction()

        readConn?.read() { transaction in
            self.mappings.update(with: transaction)

            self.collectionView.reloadData()
        }
    }
}

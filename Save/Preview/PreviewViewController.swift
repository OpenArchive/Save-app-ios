//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class PreviewViewController: UIViewController, 
                                UICollectionViewDelegateFlowLayout, UICollectionViewDataSource,
                                AssetPickerDelegate, DoneDelegate
{

    private static let segueShowDarkroom = "showDarkroomSegue"
    private static let segueShowBatchEdit = "showBatchEditSegue"


    @IBOutlet weak var uploadBt: UIBarButtonItem! {
        didSet {
            uploadBt.title = NSLocalizedString("Upload", comment: "")
        }
    }
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet var editBt: UIBarButtonItem!
    @IBOutlet var addBt: UIBarButtonItem!
    @IBOutlet var deleteBt: UIBarButtonItem!

    private let sc = SelectedCollection()

    private lazy var assetPicker = AssetPicker(self)


    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = NSLocalizedString("Preview", comment: "")
        navigationItem.titleView = title

        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "btUpload"

        collectionView.register(PreviewCell.nib, forCellWithReuseIdentifier: PreviewCell.reuseId)
        collectionView.allowsMultipleSelection = true

        if #available(iOS 14.0, *) {
            collectionView.allowsMultipleSelectionDuringEditing = true
        }

        Db.add(observer: self, #selector(yapDatabaseModified))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        updateTitle()

        toggleToolbar(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Delay. Otherwise, the alert would be shown before the view controller,
        // which effectively hides it.
        DispatchQueue.main.async {
            BatchInfoAlert.presentIfNeeded(self, additionalCondition: self.sc.count > 1)
        }
    }


    // MARK: UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sc.sections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sc.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PreviewCell.reuseId, for: indexPath) as! PreviewCell
        cell.asset = sc.getAsset(indexPath)

        return cell
    }


    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let layout = collectionViewLayout as? UICollectionViewFlowLayout
        let space = (layout?.minimumInteritemSpacing ?? 0) + (layout?.sectionInset.left ?? 0) + (layout?.sectionInset.right ?? 0)
        let size = (collectionView.frame.size.width - space) / 2

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // If the currently selected number of items is exactly one, that means,
        // that there was no selection before, and this item was just selected.
        // In that case, ignore the selection and instead move to DarkroomViewController.
        // Because in this scenario, the first selection is done by a long press,
        // which basically enters an "edit" mode. (See #longPressItem.)
        if collectionView.numberOfSelectedItems != 1 {

            // For an unkown reason, this isn't done automatically.
            collectionView.cellForItem(at: indexPath)?.isSelected = true

            return
        }

        collectionView.deselectItem(at: indexPath, animated: false)

        performSegue(withIdentifier: Self.segueShowDarkroom, sender: (indexPath.row, nil as DarkroomViewController.DirectEdit?))
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        // For an unkown reason, this isn't done automatically.
        collectionView.cellForItem(at: indexPath)?.isSelected = false

        if collectionView.numberOfSelectedItems == 0 {
            toggleToolbar(false)
        }
    }


    // MARK: AssetPickerDelegate

    var currentCollection: Collection? {
        sc.collection
    }

    func picked() {
        // Should be automatically updated via database.
    }


    // MARK: DoneDelegate

    func done() {
        navigationController?.popViewController(animated: true)
    }


    // MARK: Navigation

     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? DarkroomViewController {
            if let (index, directEdit) = sender as? (Int, DarkroomViewController.DirectEdit?) {
                vc.selected = index
                vc.directEdit = directEdit
                vc.addMode = true
            }
        }
        else if let vc = segue.destination as? BatchEditViewController {
            vc.assets = sender as? [Asset]
        }
        else if let vc = segue.destination as? ManagementViewController {
            vc.delegate = self
        }
     }


    // MARK: Actions

    @IBAction func upload() {
        Db.writeConn?.asyncReadWrite { transaction in
            var order = 0

            transaction.iterateKeysAndObjects(inCollection: Upload.collection) { (key, upload: Upload, stop) in
                if upload.order >= order {
                    order = upload.order + 1
                }
            }

            guard let group = self.sc.group else {
                return
            }

            if let id = self.sc.id,
                let collection = transaction.object(forKey: id, inCollection: Collection.collection) as? Collection {

                collection.close()

                transaction.setObject(collection, forKey: collection.id,
                                      inCollection: Collection.collection)
            }

            (transaction.ext(AbcFilteredByCollectionView.name) as? YapDatabaseViewTransaction)?
                .iterateKeysAndObjects(inGroup: group) { collection, key, object, index, stop in

                    if let asset = object as? Asset {
                        // ProofMode might have been switched on in between import and now,
                        // or something inhibited proof generation, so make sure,
                        // proof is generated before upload.
                        // Proofing will set asset to un-ready, so upload will not start
                        // before proof is done as asset is set to ready again.
                        if asset.isReady && !asset.hasProof && Settings.proofMode {
                            asset.generateProof {
                                asset.update { asset in
                                    asset.isReady = true
                                }
                            }
                        }

                        let upload = Upload(order: order, asset: asset)
                        transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                        order += 1
                    }
            }

            let count = transaction.numberOfKeys(inCollection: Upload.collection)

            DispatchQueue.main.async {
                OrbotManager.shared.alertOrbotStopped(count: count) { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }

    @IBAction func longPressCell(_ sender: UILongPressGestureRecognizer) {

        // We only recognize this the first time, it is triggered.
        // It will continue triggering with .changed and .ended states, but
        // .ended is only released after the user lifts the finger which feels
        // awkward.
        if sender.state != .began {
            return
        }

        if let indexPath = collectionView.indexPathForItem(at: sender.location(in: collectionView)) {
            collectionView.cellForItem(at: indexPath)?.isSelected = true
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)

            toggleToolbar(true)
        }
    }

    @IBAction func editAssets() {
        let count = collectionView.numberOfSelectedItems

        if count == 1 {
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                // Trigger deselection, so edit mode UI goes away.
                collectionView.deselectItem(at: indexPath, animated: false)
                collectionView(collectionView, didDeselectItemAt: indexPath)

                // Trigger selection, so DarkroomViewController gets pushed.
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
                collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
        else if count > 1 {
            performSegue(withIdentifier: Self.segueShowBatchEdit, sender: getSelectedAssets())
        }
    }

    @IBAction func addAssets() {
        assetPicker.pickMedia()
    }

    @IBAction func removeAssets() {
        present(RemoveAssetAlert(getSelectedAssets(), { [weak self] success in
            guard success else {
                return
            }

            self?.toggleToolbar(false)
        }), animated: true)
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let (forceFull, sectionChanges, rowChanges) = sc.yapDatabaseModified()

        updateTitle()

        if forceFull {
            collectionView.reloadData()

            return
        }

        if sectionChanges.count < 1 && rowChanges.count < 1 {
            return
        }

        collectionView.performBatchUpdates {
            for change in sectionChanges {
                switch change.type {
                case .delete:
                    collectionView.deleteSections(IndexSet(integer: Int(change.index)))

                case .insert:
                    collectionView.insertSections(IndexSet(integer: Int(change.index)))

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
                @unknown default:
                    break
                }
            }
        } completion: { [weak self] _ in
            if self?.sc.count ?? 0 < 1 {
                // When we don't have any assets anymore after an update, because the
                // user deleted them, it doesn't make sense, to show this view
                // controller anymore. So we leave here.
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }


    // MARK: Private Methods

    private func updateTitle() {
        let projectName = sc.collection?.project.name
        (navigationItem.titleView as? MultilineTitle)?.subtitle.text = projectName == nil ? nil : String(format: NSLocalizedString("Upload to %@", comment: ""), projectName!)
    }

    /**
     Shows different buttons on the toolbar, depending on the `selected` parameter.

     - parameter selected: true, to show icons for editing, false to show icon for adding.
     */
    private func toggleToolbar(_ selected: Bool, animated: Bool = true) {
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        if selected {
            toolbar.setItems([editBt, flexibleSpace, deleteBt], animated: animated)
        }
        else {
            toolbar.setItems([flexibleSpace, addBt, flexibleSpace], animated: animated)
        }
    }

    private func getSelectedAssets() -> [Asset] {
        var assets = [Asset]()

        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            if let asset = sc.getAsset(indexPath) {
                assets.append(asset)
            }
        }

        return assets
    }
}

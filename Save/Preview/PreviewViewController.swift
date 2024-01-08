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
            uploadBt.accessibilityIdentifier = "btUpload"
        }
    }
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet var editBt: UIBarButtonItem!
    @IBOutlet var addBt: UIBarButtonItem!
    @IBOutlet var deleteBt: UIBarButtonItem!

    private let sc = SelectedCollection()

    private lazy var assetPicker = AssetPicker(self)

    private lazy var flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)


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

        toggleToolbar(collectionView.numberOfSelectedItems != 0, animated: animated)
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

        performSegue(withIdentifier: Self.segueShowDarkroom, sender: indexPath.row)
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
            if let index = sender as? Int {
                vc.selected = index
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
        UploadInfoAlert.presentIfNeeded(self) {
            Db.writeConn?.asyncReadWrite { tx in
                guard let group = self.sc.group else {
                    return
                }

                var order = 0

                tx.iterate { (key, upload: Upload, stop) in
                    if upload.order >= order {
                        order = upload.order + 1
                    }
                }

                if let collection: Collection = tx.object(for: self.sc.id) {
                    collection.close()

                    tx.setObject(collection)
                }

                tx.iterate(group: group, in: AbcFilteredByCollectionView.name) { (collection, key, asset: Asset, index, stop) in
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
                    tx.setObject(upload)
                    order += 1
                }

                let count = UploadsView.countUploading(tx)

                DispatchQueue.main.async {
                    OrbotManager.shared.alertCannotUpload(count: count) { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
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

        if count < 2 {
            let indexPath = collectionView.indexPathsForSelectedItems?.first ?? IndexPath(row: 0, section: 0)

            // Trigger selection, so DarkroomViewController gets pushed.
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
            collectionView(collectionView, didSelectItemAt: indexPath)
        }
        else {
            performSegue(withIdentifier: Self.segueShowBatchEdit, sender: getSelectedAssets())
        }
    }

    @IBAction func addAssets() {
        assetPicker.pickMedia()
    }

    @IBAction func removeAssets() {
        RemoveAssetAlert.present(self, getSelectedAssets(), { [weak self] success in
            guard success else {
                return
            }

            self?.toggleToolbar(false)
        })
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let changes = sc.yapDatabaseModified()

        updateTitle()

        collectionView.apply(changes) { [weak self] _ in
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
        (navigationItem.titleView as? MultilineTitle)?.subtitle.text = projectName == nil 
            ? nil
            : String(format: NSLocalizedString("Upload to %@", comment: ""), projectName!)
    }

    /**
     Shows different buttons on the toolbar, depending on the `selected` parameter.

     - parameter selected: true, to show icons for editing, false to show icon for adding.
     */
    private func toggleToolbar(_ selected: Bool, animated: Bool = true) {
        var items: [UIBarButtonItem] = [editBt, flexibleSpace, addBt, flexibleSpace]

        if selected {
            items.append(deleteBt)
        }

        toolbar.setItems(items, animated: animated)
    }

    private func getSelectedAssets() -> [Asset] {
        sc.getAssets(collectionView.indexPathsForSelectedItems)
    }
}

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
            uploadBt.title = NSLocalizedString("UPLOAD", comment: "")
            uploadBt.accessibilityIdentifier = "btUpload"
        }
    }
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet var editBt: UIButton!{
        didSet {
            editBt.isHidden = true
        }
    }
    
    @IBOutlet weak var selectAllBt: UIButton!{
        didSet{
            selectAllBt.isHidden = true
            selectAllBt.titleLabel?.font =  .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
        }
    }
    @IBOutlet var addBt: UIButton!
    @IBOutlet var deleteBt: UIButton!{
        didSet {
            deleteBt.isHidden = true
        }
    }
    
    private let sc = SelectedCollection()
    
    private lazy var assetPicker = AssetPicker(self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let  title = NSLocalizedString("Preview Upload", comment: "")
        navigationItem.title = title
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
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
        toggleToolbar(collectionView.numberOfSelectedItems != 0, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("MediaPreview")
        DispatchQueue.main.async {
            BatchInfoAlert.presentIfNeeded(viewController: self, additionalCondition: self.sc.count >= 1)
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
            let totalItems = collectionView.numberOfItems(inSection: 0)
                    if collectionView.numberOfSelectedItems == totalItems {
                        selectAllBt.setTitle(NSLocalizedString("Deselect All", comment: ""), for: .normal)
                    }
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
            } else {
                selectAllBt.setTitle(NSLocalizedString("Select All", comment: ""), for: .normal)
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
        UploadInfoAlert.presentIfNeeded(viewController: self) {
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
                    //commented by navoda : no need to generate proof mode when uploading.
                    //                    if asset.isReady && !asset.hasProof && Settings.proofMode {
                    //                        asset.generateProof {
                    //                            asset.update { asset in
                    //                                asset.isReady = true
                    //                            }
                    //                        }
                    //                    }
                    
                    let upload = Upload(order: order, asset: asset)
                    tx.setObject(upload)
                    order += 1
                }
                
                let count = UploadsView.countUploading(tx)
                
                DispatchQueue.main.async {
                    self.alertCannotUploadNoWifi(count: count) { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }
    func showMediaPickerSheet() {
        
        
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
    
    @IBAction func showAddMenu() {
        showMediaPickerSheet()
        
    }
    @IBAction func longPressCell(_ sender: UILongPressGestureRecognizer) {
        
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
    
    @IBAction func selectAllAssets(_ sender: Any) {
        let totalItems = collectionView.numberOfItems(inSection: 0)
           
           let allSelected = collectionView.indexPathsForSelectedItems?.count == totalItems
           
           if allSelected {
             
               for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
                   collectionView.deselectItem(at: indexPath, animated: false)
                   collectionView.cellForItem(at: indexPath)?.isSelected = false
               }
               toggleToolbar(false)
               selectAllBt.setTitle(NSLocalizedString("Select All", comment: ""), for: .normal)
           } else {
               for item in 0..<totalItems {
                   let indexPath = IndexPath(item: item, section: 0)
                   collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                   collectionView.cellForItem(at: indexPath)?.isSelected = true
               }
               toggleToolbar(true)
               selectAllBt.setTitle(NSLocalizedString("Deselect All", comment: ""), for: .normal)
           }
    }
    @IBAction func addAssets() {
        assetPicker.pickMedia()
    }
    
    @IBAction func removeAssets() {
        let assetsToRemove = getSelectedAssets()
        
        guard !assetsToRemove.isEmpty else { return }
        
        // Clear selection first to avoid UI inconsistencies
        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: indexPath, animated: false)
            collectionView.cellForItem(at: indexPath)?.isSelected = false
        }
        
        toggleToolbar(false)
        
        // Remove all assets in a batch operation
        let group = DispatchGroup()
        
        for asset in assetsToRemove {
            group.enter()
            asset.remove {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // All deletions completed
            // The UI will be updated via yapDatabaseModified notification
        }
    }
    
    
    // MARK: Observers
    
    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     
     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let changes = sc.yapDatabaseModified()
        
        updateTitle()
        
        // Check if we're about to have an empty collection
        let willBeEmpty = sc.count < 1
        
        // If multiple deletions, force full, or will be empty, just reload
        let deleteCount = changes.rowChanges.filter { $0.type == .delete }.count
        
        if changes.forceFull || deleteCount > 1 || willBeEmpty {
            UIView.performWithoutAnimation {
                collectionView.reloadData()
            }
            
            if willBeEmpty {
                navigationController?.popViewController(animated: true)
            }
            return
        }
        
        collectionView.apply(changes) { [weak self] _ in
            if self?.sc.count ?? 0 < 1 {
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
        
        deleteBt.isHidden = !selected
        editBt.isHidden = !selected
        selectAllBt.isHidden = !selected
        addBt.isHidden = selected
        
    }
    
    private func getSelectedAssets() -> [Asset] {
        sc.getAssets(collectionView.indexPathsForSelectedItems)
    }
    
    func alertCannotUploadNoWifi(count: Int? = nil, _ completed: (() -> Void)? = nil) {
        guard Settings.wifiOnly && UploadManager.shared.reachability?.connection == .unavailable,
              let topVc = UIApplication.shared.delegate?.window??.rootViewController?.top
        else {
            completed?()
            return
        }
        
        var ownCount = count ?? 0
        
        if count == nil {
            Db.bgRwConn?.read { tx in
                ownCount = UploadsView.countUploading(tx)
            }
        }
        
        guard ownCount > 0 else {
            completed?()
            return
        }
        
        let message = NSLocalizedString(
            "Uploads are blocked until you connect to a Wi-Fi network or allow uploads over a mobile connection again.",
            comment: "") + "\n"
        
        let title = NSLocalizedString("Wi-Fi not connected", comment: "")
        
        let actions = [
            AlertHelper.cancelAction(NSLocalizedString("Ignore", comment: ""), handler: { 
                completed?()
            }),
            AlertHelper.destructiveAction(NSLocalizedString("Allow any connection", comment: ""), handler: { 
                Settings.wifiOnly = false
                NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
                completed?()
            })
        ]
        
        AlertHelper.present(topVc, message: message, title: title, actions: actions)
    }
}

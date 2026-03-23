//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import YapDatabase

class PreviewViewController: UIViewController, AssetPickerDelegate, DoneDelegate {
    
    // MARK: Storyboard outlet placeholders (hidden, SwiftUI handles UI)
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView?.dataSource = nil
            collectionView?.delegate = nil
            collectionView?.removeFromSuperview()
        }
    }
    @IBOutlet var editBt: UIButton! {
        didSet { editBt?.removeFromSuperview() }
    }
    @IBOutlet weak var selectAllBt: UIButton! {
        didSet { selectAllBt?.removeFromSuperview() }
    }
    @IBOutlet var addBt: UIButton! {
        didSet { addBt?.removeFromSuperview() }
    }
    @IBOutlet var deleteBt: UIButton! {
        didSet { deleteBt?.removeFromSuperview() }
    }
    
    private let sc = SelectedCollection()
    private lazy var assetPicker = AssetPicker(self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let title = NSLocalizedString("Preview Upload", comment: "")
        navigationItem.title = title
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        let uploadItem = UIBarButtonItem(
            title: NSLocalizedString("UPLOAD", comment: ""),
            style: .plain,
            target: self,
            action: #selector(upload)
        )
        uploadItem.accessibilityIdentifier = "btUpload"
        uploadItem.tintColor = .white
        navigationItem.rightBarButtonItem = uploadItem
        
        setupSwiftUIView()
    }
    
    private func setupSwiftUIView() {
        let previewView = PreviewView(
            onNavigateToDarkroom: { [weak self] index in
                self?.navigateToDarkroom(index: index)
            },
            onNavigateToBatchEdit: { [weak self] assets in
                self?.navigateToBatchEdit(assets: assets)
            },
            onAddAssets: { [weak self] in
                self?.showMediaPickerSheet()
            },
            onUploadComplete: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        
        let hostingController = UIHostingController(rootView: previewView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("MediaPreview")
        DispatchQueue.main.async {
            BatchInfoAlert.presentIfNeeded(viewController: self, additionalCondition: self.sc.count >= 1)
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
    
    private func navigateToDarkroom(index: Int) {
        let vc = DarkroomViewController()
        vc.selected = index
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func navigateToBatchEdit(assets: [Asset]) {
        let vc = BatchEditViewController()
        vc.assets = assets
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: Actions
    
    @objc private func upload() {
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
        guard presentedViewController == nil else { return }

        let popup = MediaPopupViewController()
        
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

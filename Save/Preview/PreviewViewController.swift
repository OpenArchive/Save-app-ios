//
//  PreviewViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 06.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import YapDatabase

/// Hosts the full preview flow (grid, darkroom, batch edit) in one `UIHostingController` shell.
final class PreviewViewController: UIHostingController<PreviewFlowContainerView>, AssetPickerDelegate, DoneDelegate {

    private let sc = SelectedCollection()
    private lazy var assetPicker = AssetPicker(self)
    private let session: PreviewSessionModel

    private weak var centeredTitleView: PreviewNavScreenWidthTitleView?

    init() {
        let session = PreviewSessionModel()
        self.session = session
        super.init(rootView: PreviewFlowContainerView(session: session))
        session.viewController = self
    }

    @objc required dynamic init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        save_configureTealStackNavigationItem()
        syncNavigationChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        centeredTitleView?.invalidateWidth()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("MediaPreview")
        DispatchQueue.main.async {
            BatchInfoAlert.presentIfNeeded(viewController: self, additionalCondition: self.sc.count >= 1)
        }
    }

    func syncNavigationChrome() {
        let titleText: String
        let rightItem: UIBarButtonItem
        switch session.route {
        case .preview:
            titleText = NSLocalizedString("Preview Upload", comment: "")
            rightItem = SaveNavigationBarButtons.makeChromelessPrimaryActionBarButtonItem(
                title: NSLocalizedString("UPLOAD", comment: ""),
                target: self,
                action: #selector(upload),
                accessibilityIdentifier: "btUpload"
            )
        case .darkroom:
            titleText = NSLocalizedString("Edit Media Info", comment: "")
            rightItem = SaveNavigationBarButtons.makeChromelessPrimaryActionBarButtonItem(
                title: "DONE",
                target: self,
                action: #selector(doneTapped),
                accessibilityIdentifier: nil
            )
        case .batchEdit:
            titleText = NSLocalizedString("Bulk Edit Media Info", comment: "")
            rightItem = SaveNavigationBarButtons.makeChromelessPrimaryActionBarButtonItem(
                title: "DONE",
                target: self,
                action: #selector(doneTapped),
                accessibilityIdentifier: nil
            )
        }

        navigationItem.title = nil
        let titleView = PreviewNavScreenWidthTitleView(host: self, text: titleText)
        centeredTitleView = titleView
        navigationItem.titleView = titleView
        navigationItem.rightBarButtonItem = rightItem

        // Inner routes (darkroom / batch) live inside this VC; the system back would pop to main.
        switch session.route {
        case .preview:
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = false
            let canPopShell = (navigationController?.viewControllers.count ?? 0) > 1
            navigationController?.interactivePopGestureRecognizer?.isEnabled = canPopShell
        case .darkroom, .batchEdit:
            navigationItem.hidesBackButton = true
            let back = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(previewInnerBackTapped)
            )
            back.tintColor = .white
            back.accessibilityLabel = NSLocalizedString("Back", comment: "")
            navigationItem.leftBarButtonItem = back
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    @objc private func previewInnerBackTapped() {
        session.returnToPreview()
    }

    @objc private func doneTapped() {
        session.returnToPreview()
    }

    func popFromMainNavigation() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: AssetPickerDelegate

    var currentCollection: Collection? {
        sc.collection
    }

    func picked() {
        // Database-driven refresh.
    }

    // MARK: DoneDelegate

    func done() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: Upload

    @objc private func upload() {
        UploadInfoAlert.presentIfNeeded(viewController: self) {
            var uploadCount: Int = 0

            Db.writeConn?.asyncReadWrite({ tx in
                guard let group = self.sc.group else {
                    return
                }

                var order = 0

                tx.iterate { (_, upload: Upload, _) in
                    if upload.order >= order {
                        order = upload.order + 1
                    }
                }

                if let collection: Collection = tx.object(for: self.sc.id) {
                    collection.close()
                    tx.setObject(collection)
                }

                tx.iterate(group: group, in: AbcFilteredByCollectionView.name) { (_, _, asset: Asset, _, _) in
                    let upload = Upload(order: order, asset: asset)
                    tx.setObject(upload)
                    order += 1
                }

                uploadCount = UploadsView.countUploading(tx)
            }, completionBlock: {
                DispatchQueue.main.async {
                    self.alertCannotUploadNoWifi(count: uploadCount) { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            })
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
            comment: ""
        ) + "\n"

        let title = NSLocalizedString("Wi-Fi not connected", comment: "")

        let actions = [
            AlertHelper.cancelAction(NSLocalizedString("Ignore", comment: ""), handler: {
                completed?()
            }),
            AlertHelper.destructiveAction(NSLocalizedString("Allow any connection", comment: ""), handler: {
                Settings.wifiOnly = false
                NotificationCenter.default.post(name: .uploadManagerDataUsageChange, object: Settings.wifiOnly)
                completed?()
            }),
        ]

        AlertHelper.present(topVc, message: message, title: title, actions: actions)
    }
}

// MARK: - Centered nav title (screen width)

/// `navigationItem.title` is laid out between the bar buttons (reads left-heavy). A full-window-width
/// `titleView` keeps the label’s centered text aligned with the screen center.
private final class PreviewNavScreenWidthTitleView: UIView {

    weak var host: UIViewController?
    private let label = UILabel()

    init(host: UIViewController, text: String) {
        self.host = host
        super.init(frame: .zero)
        backgroundColor = .clear
        label.text = text
        label.textColor = .white
        label.font = UIFont(name: "Montserrat-SemiBold", size: 18)
            ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func invalidateWidth() {
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        let w = host?.view.window?.bounds.width
            ?? host?.view.bounds.width
            ?? UIScreen.main.bounds.width
        return CGSize(width: w, height: 44)
    }
}

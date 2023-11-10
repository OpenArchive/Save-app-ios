//
//  AssetPicker.swift
//  Save
//
//  Created by Benjamin Erhart on 10.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Foundation
import TLPhotoPicker
import Photos
import LegacyUTType

protocol AssetPickerDelegate: AnyObject {

    var currentCollection: Collection? { get }

    func picked()
}

class AssetPicker: NSObject, TLPhotosPickerViewControllerDelegate, UIDocumentPickerDelegate {

    private weak var delegate: UIViewController?

    private lazy var pickerConf: TLPhotosPickerConfigure = {
        var conf = TLPhotosPickerConfigure()
        conf.customLocalizedTitle = ["Camera Roll": NSLocalizedString("Camera Roll", comment: "")]
        conf.tapHereToChange = NSLocalizedString("Tap here to change", comment: "")
        conf.cancelTitle = NSLocalizedString("Cancel", comment: "")
        conf.doneTitle = NSLocalizedString("Done", comment: "")
        conf.emptyMessage = NSLocalizedString("No albums", comment: "")
        conf.allowedAlbumCloudShared = true
        conf.recordingVideoQuality = .typeHigh
        conf.selectedColor = .accent

        return conf
    }()


    init(_ delegate: UIViewController) {
        self.delegate = delegate
    }

    func pickMedia() {
        let tlpp = TLPhotosPickerViewController()
        tlpp.delegate = self
        tlpp.configure = pickerConf

        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            delegate?.present(tlpp, animated: true)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization() { newStatus in
                if newStatus == .authorized {
                    DispatchQueue.main.async {
                        self.delegate?.present(tlpp, animated: true)
                    }
                }
            }

        case .restricted:
            guard let controller = delegate else {
                break
            }

            AlertHelper.present(
                controller, message: NSLocalizedString("Sorry, you are not allowed to view the camera roll.", comment: ""),
                title: NSLocalizedString("Access Restricted", comment: ""),
                actions: [AlertHelper.cancelAction()])

        case .denied:
            guard let controller = delegate else {
                break
            }

            showMissingPermissionAlert(controller)

        @unknown default:
            break
        }
    }

    func pickDocuments() {
        let vc = UIDocumentPickerViewController(documentTypes: [LegacyUTType.item.identifier], in: .import)
        vc.delegate = self

        delegate?.present(vc, animated: true)
    }


    // MARK: TLPhotosPickerViewControllerDelegate

    func dismissPhotoPicker(withPHAssets assets: [PHAsset]) {
        guard let collection = (delegate as? AssetPickerDelegate)?.currentCollection,
              assets.count > 0
        else {
            return
        }

        for asset in assets {
            let id = UIApplication.shared.beginBackgroundTask()

            AssetFactory.create(fromPhasset: asset, collection) { asset in
                UIApplication.shared.endBackgroundTask(id)
            }
        }

        AbcFilteredByCollectionView.updateFilter(collection.id)

        (delegate as? AssetPickerDelegate)?.picked()
    }

    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        showMissingPermissionAlert(picker)
    }

    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        showMissingPermissionAlert(
            picker, NSLocalizedString(
                "Please go to the Settings app to grant this app access to your camera, if you want to upload photos or videos.",
                comment: ""))
    }


    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let collection = (delegate as? AssetPickerDelegate)?.currentCollection,
              controller.documentPickerMode == .import
                && urls.count > 0
        else {
            return
        }

        for url in urls {
            let id = UIApplication.shared.beginBackgroundTask()

            AssetFactory.create(fromFileUrl: url, collection) { asset in
                UIApplication.shared.endBackgroundTask(id)
            }
        }

        AbcFilteredByCollectionView.updateFilter(collection.id)

        (delegate as? AssetPickerDelegate)?.picked()
    }


    // MARK: Private Methods

    private func showMissingPermissionAlert(_ controller: UIViewController, _ message: String? = nil) {
        var actions = [AlertHelper.cancelAction()]

        if let url = URL(string: UIApplication.openSettingsURLString) {
            actions.append(AlertHelper.defaultAction(NSLocalizedString("Settings", comment: ""), handler: { _ in
                UIApplication.shared.open(url)
            }))
        }

        AlertHelper.present(
            controller,
            message: message ?? NSLocalizedString(
                "Please go to the Settings app to grant this app access to your photo library, if you want to upload photos or videos.",
                comment: ""),
            title: NSLocalizedString("Access Denied", comment: ""),
            actions: actions)
    }
}

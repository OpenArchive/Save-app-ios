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

class AssetPicker: NSObject, TLPhotosPickerViewControllerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate & UINavigationControllerDelegate {

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
    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showMissingPermissionAlert(
                delegate ?? UIViewController(),
                NSLocalizedString("Camera is not available on this device.", comment: "")
            )
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.presentCamera()
                    }
                }
            }

        case .denied, .restricted:
            showMissingPermissionAlert(
                delegate ?? UIViewController(),
                NSLocalizedString("Please go to the Settings app to grant this app access to your camera.", comment: "")
            )

        @unknown default:
            break
        }
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.mediaTypes = ["public.image"]
        delegate?.present(picker, animated: true)
    }


    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

           picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let collection = (delegate as? AssetPickerDelegate)?.currentCollection
        else {
            return
        }

        let id = UIApplication.shared.beginBackgroundTask()
           if let mediaURL = info[.mediaURL] as? URL {
               // Video captured
               AssetFactory.create(fromFileUrl: mediaURL, collection) { asset in
                   UIApplication.shared.endBackgroundTask(id)
               }
           }
           else if let image = info[.originalImage] as? UIImage {
               // Photo captured
               if let imageData = image.jpegData(compressionQuality: 1.0) {
                   AssetFactory.create(from: imageData, uti: LegacyUTType.jpeg, name: "captured.jpg", thumbnail: image, collection) { asset in
                       UIApplication.shared.endBackgroundTask(id)
                   }
               }
           }
        AbcFilteredByCollectionView.updateFilter(collection.id)

        (delegate as? AssetPickerDelegate)?.picked()
       }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }


}

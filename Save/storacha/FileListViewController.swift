//
//  FileListViewController.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import Photos
import PhotosUI
import AVFoundation

class FileListViewController: UIViewController {
    private let appState: StorachaAppState
    private let space: StorachaSpace
    
    init(appState: StorachaAppState, space: StorachaSpace) {
        self.appState = appState
        self.space = space
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = space.name
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        if(space.isAdmin){
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("MANAGE ACCESS", comment: ""),
                style: .plain,
                target: self,
                action: #selector(manageDIDsTapped)
            )}
        
        if #available(iOS 14.0, *) {
            let contentView = FileListView(
                spaceDid: space.id,
                onUploadTapped: {
                    if !self.appState.spaceState.isUploading {
                        self.showUploadOptions()
                    }
                }, isSpaceAdmin: true
            )
            .environmentObject(appState.spaceState)
            
            let hosting = UIHostingController(rootView: contentView)
            addChild(hosting)
            view.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hosting.didMove(toParent: self)
        }
    }
    
    private func showUploadOptions() {
        let alert = UIAlertController(title: "Upload File", message: "Choose upload source", preferredStyle: .actionSheet)
        
        // Camera option
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
                self.requestCameraPermission {
                    self.presentCamera()
                }
            })
        }
        
        // Photo Library option
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.requestPhotoLibraryPermission {
                self.presentPhotoLibrary()
            }
        })
        
        // Document picker option
        alert.addAction(UIAlertAction(title: "Files", style: .default) { _ in
            self.presentFilePicker()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func requestCameraPermission(completion: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion()
                    } else {
                        self.showPermissionAlert(for: "Camera")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(for: "Camera")
        @unknown default:
            showPermissionAlert(for: "Camera")
        }
    }
    
    private func requestPhotoLibraryPermission(completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            completion()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        completion()
                    } else {
                        self.showPermissionAlert(for: "Photo Library")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(for: "Photo Library")
        @unknown default:
            showPermissionAlert(for: "Photo Library")
        }
    }
    
    private func showPermissionAlert(for source: String) {
        let alert = UIAlertController(
            title: "\(source) Access Required",
            message: "Please grant access to \(source) in Settings to upload files.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    private func presentPhotoLibrary() {
        if #available(iOS 14.0, *) {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = nil // Allow all media types
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            // Fallback for iOS 13
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.image", "public.movie"]
            picker.delegate = self
            picker.allowsEditing = false
            present(picker, animated: true)
        }
    }
    
    private func presentFilePicker() {
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
        }
    }
    
    private func uploadFile(from url: URL, isTemporary: Bool = false) {
        print("Uploading file: \(url.lastPathComponent)")
        
        Task { @MainActor in
            // Upload the file
            await appState.spaceState.uploadFile(
                fileURL: url,
                spaceDid: space.id,
                isAdmin: space.isAdmin
            )
            
            // Clean up temporary file if needed
            if isTemporary {
                try? FileManager.default.removeItem(at: url)
            }
            
            // Note: File list will be refreshed automatically by the SwiftUI view
            // when uploadResult changes to success in the onChange modifier
        }
    }
    
    private func saveMediaToTemporaryFile(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error saving temporary file: \(error)")
            return nil
        }
    }
    
    @objc func manageDIDsTapped() {
        let vc = ManageDIDsViewController(didState: appState.didState, spaceDid: space.id)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension FileListViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            // Start upload after picker is dismissed to show overlay properly
            if let image = info[.originalImage] as? UIImage {
                // Handle image
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
                let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                
                if let tempURL = self?.saveMediaToTemporaryFile(data: imageData, fileName: fileName) {
                    self?.uploadFile(from: tempURL, isTemporary: true)
                }
                
            } else if let videoURL = info[.mediaURL] as? URL {
                // Handle video
                self?.uploadFile(from: videoURL)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
@available(iOS 14.0, *)
extension FileListViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let result = results.first else { return }
            
            // Handle images
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    if let image = object as? UIImage,
                       let imageData = image.jpegData(compressionQuality: 0.8) {
                        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                        
                        DispatchQueue.main.async {
                            if let tempURL = self?.saveMediaToTemporaryFile(data: imageData, fileName: fileName) {
                                self?.uploadFile(from: tempURL, isTemporary: true)
                            }
                        }
                    }
                }
            }
            // Handle videos and other files
            else if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
                    guard let url = url, error == nil else { return }
                    
                    // Copy to temporary location
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "video_\(Date().timeIntervalSince1970).\(url.pathExtension)"
                    let tempURL = tempDir.appendingPathComponent(fileName)
                    
                    do {
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self?.uploadFile(from: tempURL, isTemporary: true)
                        }
                    } catch {
                        print("Error copying video file: \(error)")
                    }
                }
            }
            // Handle other file types
            else {
                let typeIdentifier = result.itemProvider.registeredTypeIdentifiers.first ?? "public.data"
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
                    guard let url = url, error == nil else { return }
                    
                    // Copy to temporary location
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "file_\(Date().timeIntervalSince1970).\(url.pathExtension)"
                    let tempURL = tempDir.appendingPathComponent(fileName)
                    
                    do {
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self?.uploadFile(from: tempURL, isTemporary: true)
                        }
                    } catch {
                        print("Error copying file: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension FileListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let picked = urls.first else { return }
        
        // Start upload after a brief delay to ensure picker is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.uploadFile(from: picked)
        }
    }
}

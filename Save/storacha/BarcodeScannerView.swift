//
//  BarcodeScannerView.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    @Binding var isPresented: Bool  // Add this binding

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onDismiss = {
            isPresented = false  // Dismiss when cancel tapped
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        var onDismiss: (() -> Void)?  // Add dismiss callback
        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        
        override func viewDidLoad() {
            super.viewDidLoad()
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            checkCameraPermission()
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }
        
        private func checkCameraPermission() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCamera()
                
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            self.setupCamera()
                        } else {
                            self.showPermissionDeniedAlert()
                        }
                    }
                }
                
            case .denied, .restricted:
                showPermissionDeniedAlert()
                
            @unknown default:
                showPermissionDeniedAlert()
            }
        }
        
        private func setupCamera() {
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                showCameraUnavailableAlert()
                return
            }
            
            guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                showCameraUnavailableAlert()
                return
            }

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                showCameraUnavailableAlert()
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr, .code128, .code39, .code93]
            } else {
                showCameraUnavailableAlert()
                return
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
        
        private func showPermissionDeniedAlert() {
            DispatchQueue.main.async {
                guard self.isViewLoaded && self.view.window != nil else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showPermissionDeniedAlert()
                    }
                    return
                }
                
                let alert = UIAlertController(
                    title: NSLocalizedString("Camera Access Required", comment: ""),
                    message: NSLocalizedString("Please enable camera access in Settings to scan QR codes.", comment: ""),
                    preferredStyle: .alert
                )
                
                // Call onDismiss when Cancel is tapped
                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    self.onDismiss?()
                })
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: ""), style: .default) { _ in
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                })
                
                self.present(alert, animated: true)
            }
        }
        
        private func showCameraUnavailableAlert() {
            DispatchQueue.main.async {
                guard self.isViewLoaded && self.view.window != nil else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.showCameraUnavailableAlert()
                    }
                    return
                }
                
                let alert = UIAlertController(
                    title: NSLocalizedString("Camera Unavailable", comment: ""),
                    message: NSLocalizedString("Unable to access the camera. Please try again.", comment: ""),
                    preferredStyle: .alert
                )
                
                // Call onDismiss when OK is tapped
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                    self.onDismiss?()
                })
                
                self.present(alert, animated: true)
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let scanned = object.stringValue {
                captureSession.stopRunning()
                onScan?(scanned)
            }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
}

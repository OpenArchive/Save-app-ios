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

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        private let captureSession = AVCaptureSession()

        override func viewDidLoad() {
            super.viewDidLoad()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
            guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr, .code128, .code39, .code93]
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            captureSession.startRunning()
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
    }
}
import SwiftUI

struct ScanDIDView: View {
    @ObservedObject var viewModel: ScanDIDViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showScanner = false

    var body: some View {
        if #available(iOS 14.0, *) {
            VStack(alignment: .leading, spacing: 16) {
                
                HStack {
                    TextField("Enter DID", text: $viewModel.typedDID, onCommit: {
                        viewModel.addTypedDID()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        withAnimation {
                            showScanner.toggle()
                        }
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal)

                if showScanner {
                    BarcodeScannerView { scannedValue in
                        viewModel.addScannedDID(scannedValue)
                        showScanner = false
                    }
                    .frame(height: 300)
                    .transition(.move(edge: .top))
                    .padding(.trailing,16)
                }

                Spacer()
            }
            .padding(.top, 20)
            .onChange(of: viewModel.didDetected) { _ in
                presentationMode.wrappedValue.dismiss()
            }
        } else {
            Text("Unsupported iOS version")
        }
    }
}

import Combine

class ScanDIDViewModel: ObservableObject {
    @Published var typedDID: String = ""
    @Published var didDetected: String?
    
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private let spaceId: String

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, spaceId: String) {
        self.store = store
        self.spaceId = spaceId
    }

    func addTypedDID() {
        let trimmed = typedDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.dispatch(.addDID(spaceId: spaceId, did: trimmed))
        didDetected = trimmed
    }

    func addScannedDID(_ did: String) {
        store.dispatch(.addDID(spaceId: spaceId, did: did))
        didDetected = did
    }
}

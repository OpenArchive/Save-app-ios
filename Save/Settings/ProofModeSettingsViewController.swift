//
//  ProofModeSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import Eureka
import LibProofMode

class ProofModeSettingsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("ProofMode", comment: "")
        
        if #available(iOS 14.0, *) {
            
            let settingsView = ProofModeSettingsView()
            
            let hostingController = UIHostingController(rootView: settingsView)
            
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
            hostingController.view.backgroundColor = UIColor.systemBackground
            view.backgroundColor = UIColor.systemBackground
        }
    }
}
import SwiftUI

struct ProofModeSettingsView: View {
    @State private var isProofModeEnabled = Settings.proofMode  // Initialize from Settings
    @State private var showAlert = false
    private func showLocationDeniedAlert() {
        showAlert = true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ToggleSwitch(
                title: NSLocalizedString("Enable ProofMode", comment: "Enable ProofMode"),
                subtitle: NSLocalizedString("Share ProofMode public key", comment: "Share ProofMode public key"),
                isOn: $isProofModeEnabled
            ) { value in
                Settings.proofMode = value
                if value {
                    let currentStatus = LocationManangerProofMode.shared.getAuthorizationStatus()
                    
                    switch currentStatus {
                    case .notDetermined:
                        // Request permission (first time)
                        LocationManangerProofMode.shared.requestAuthorization { status in
                            DispatchQueue.main.async {
                                if status == .authorizedWhenInUse || status == .authorizedAlways {
                                    Settings.proofMode = true
                                    isProofModeEnabled = true
                                    if !(URL.proofModePrivateKey?.exists ?? false) {
                                        Proof.shared.initializeWithDefaultKeys()
                                    }
                                } else  if status == .denied || status == .restricted{
                                    Settings.proofMode = false
                                    isProofModeEnabled = false
                                    showAlert = true
                                }
                            }
                        }
                        
                    case .authorizedWhenInUse, .authorizedAlways:
                        // Already granted
                        Settings.proofMode = true
                        isProofModeEnabled = true
                        if !(URL.proofModePrivateKey?.exists ?? false) {
                            Proof.shared.initializeWithDefaultKeys()
                        }
                        
                    case .denied, .restricted:
                        
                        Settings.proofMode = false
                        isProofModeEnabled = false
                        showAlert = true
                        
                    @unknown default:
                        break
                    }
                } else {
                    Settings.proofMode = false
                }
            }
            
            ProofModeView()
            
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(Color(UIColor.label))
                    .padding(.leading, 10)
                    .padding(.top, 16)
                
                VStack(alignment: .leading) {
                    
                    let localizedText = String(format: NSLocalizedString(
                        "To help verify where your media was captured, ProofMode gathers data from nearby cell towers to corroborate your location. To add credibility and context, it then includes a separate metadata file with your media. Neither Save nor OpenArchive will be able to access or store this location data, it will only be accessible to those with access to the server files. iOS requires location access to collect this information.",
                        comment: "Warning about ProofMode metadata"))
                    
                    if #available(iOS 15, *) {
                        Text(AttributedString.boldSubstring(in: localizedText, substring: "Neither Save nor OpenArchive will be able to access or store this location data, it will only be accessible to those with access to the server files"))
                            .font(.montserrat(.medium, for: .caption2)).foregroundColor(Color(UIColor.label))
                    } else {
                        if #available(iOS 16.0, *) {
                            Text(localizedText)
                                .font(.montserrat(.medium, for: .caption)).foregroundColor(Color(UIColor.label)).lineSpacing(6)
                                .kerning(0.3)
                        } else {
                            Text(localizedText)
                                .font(.montserrat(.medium, for: .caption)).foregroundColor(Color(UIColor.label)).lineSpacing(6)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom,16)
                .padding(.trailing, 10)
            }
            .background(Color.gray05)
            .cornerRadius(10)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Group {
                if showAlert {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Location Permission Required", comment: ""),
                                    message: NSLocalizedString("Please enable location access in Settings to use ProofMode.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Open Settings", comment: ""),
                                    iconImage:  Image(systemName: "exclamationmark.triangle.fill"),
                                    primaryButtonAction: {
                                        showAlert = false
                                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(appSettings)
                                        }
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    secondaryButtonAction: {
                                        showAlert = false
                                    },
                                    showCheckbox: false, isRemoveAlert: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
            })
    }
    struct ProofModeView: View {
        var body: some View {
            Text(NSLocalizedString("ProofMode is a system that enables authentication and verification of multimedia content,", comment: "ProofMode description"))
                .font(.montserrat(.medium, for: .caption))
                .foregroundColor(.primary)
            +
            Text("[\(NSLocalizedString(" learn more here", comment: "Learn more link"))](https://proofmode.org)")
                .font(.montserrat(.medium, for: .caption))
                .foregroundColor(.accent)
                .underline()
        }
    }
    
    /// **Handles ProofMode toggle logic**
    private func handleProofModeToggle(_ isEnabled: Bool) {
        Settings.proofMode = isEnabled
        
        if Settings.proofMode {
            
            LocationMananger.shared.requestAuthorization { status in
                
                if !(URL.proofModePrivateKey?.exists ?? false) {
                    
                    Proof.shared.initializeWithDefaultKeys()
                }
            }
        }
    }
}

struct ProofModeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProofModeSettingsView()
    }
}

@available(iOS 15, *)
extension AttributedString {
    static func boldSubstring(in text: String, substring: String) -> AttributedString {
        var attributedString = AttributedString(text)
        if let range = attributedString.range(of: substring) {
            attributedString[range].font =  (.montserrat(.boldItalic, for: .caption2))
        }
        return attributedString
    }
}

import CoreLocation

class LocationManangerProofMode: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationManangerProofMode()
    
    private let locationManager = CLLocationManager()
    private var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    
    override private init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestAuthorization(onChange: @escaping (CLAuthorizationStatus) -> Void) {
        self.onAuthorizationChange = onChange
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getAuthorizationStatus() -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        } else {
            // For iOS < 14, use legacy API
            return CLLocationManager.authorizationStatus()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        onAuthorizationChange?(status)
    }
}

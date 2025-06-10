//
//  ProofModeSettingsView.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import LibProofMode

struct ProofModeSettingsView: View {
    @State private var isProofModeEnabled = Settings.proofMode  // Initialize from Settings
    @State private var showAlert = false
    @State private var userManuallyToggledOn = false
    @State private var lastPermissionStatus: CLAuthorizationStatus = LocationManangerProofMode.shared.status
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
                    userManuallyToggledOn = true
                    
                    let currentStatus = LocationManangerProofMode.shared.status
                    
                    switch currentStatus {
                    case .notDetermined:
                        LocationManangerProofMode.shared.requestAuthorization()
                        
                    case .authorizedWhenInUse, .authorizedAlways:
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
                    userManuallyToggledOn = false
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
        .onAppear {
            LocationManangerProofMode.shared.monitorAuthorizationChanges { status in
                DispatchQueue.main.async {
                    guard status != lastPermissionStatus else { return }
                    lastPermissionStatus = status
                    
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        
                        if userManuallyToggledOn {
                            Settings.proofMode = true
                            isProofModeEnabled = true
                            if !(URL.proofModePrivateKey?.exists ?? false) {
                                Proof.shared.initializeWithDefaultKeys()
                            }
                        }
                    } else if status == .denied || status == .restricted {
                        Settings.proofMode = false
                        isProofModeEnabled = false
                        showAlert = true
                    }
                }
            }
        }
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

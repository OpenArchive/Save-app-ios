//
//  ProofModeSettingsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import CoreLocation
import LibProofMode
import SwiftUI
import UIKit

@available(iOS 14.0, *)
final class ProofModeSettingsViewController: UIHostingController<ProofModeSettingsView> {

    init() {
        super.init(rootView: ProofModeSettingsView())
    }

    @objc required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("ProofMode", comment: "")
        save_configureTealStackNavigationItem()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("ProofMode")
    }
}

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
                subtitle: "",
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
                        trackFeatureToggled(featureName: "proof_mode", enabled: true)
                        if !(URL.proofModePrivateKey?.exists ?? false) {
                            Proof.shared.initializeWithDefaultKeys()
                        }
                        
                    case .denied, .restricted:
                        Settings.proofMode = false
                        isProofModeEnabled = false
                        trackFeatureToggled(featureName: "proof_mode", enabled: false)
                        showAlert = true
                        
                    @unknown default:
                        break
                    }
                } else {
                    userManuallyToggledOn = false
                    Settings.proofMode = false
                    trackFeatureToggled(featureName: "proof_mode", enabled: false)
                }
            }
            
            ProofModeView()
            
            HStack(alignment: .top) {
                Image("ic_error")
                    .foregroundColor(Color(UIColor.label))
                    .padding(.leading, 10)
                    .padding(.top, 16)
                
                VStack(alignment: .leading) {
                    
                    let localizedText = NSLocalizedString(
                        "To help verify where your media was captured, ProofMode gathers data from nearby cell towers to corroborate your location. To add credibility and context, it then includes a separate metadata file with your media*. iOS requires location access to collect this information.",
                        comment: "Warning about ProofMode metadata"
                    )

                    let localizedTextPart2 = NSLocalizedString(
                        "*Neither **_Save_** nor **_OpenArchive_** will be able to access or store this location data, it will only be accessible to those with access to the server files.",
                        comment: "Warning about ProofMode metadata"
                    )

                    if #available(iOS 16.0, *) {
                      
                        if let attributed = try? AttributedString(markdown: localizedText) {
                            Text(attributed)
                                .font(.montserrat(.medium, for: .caption))
                                .foregroundColor(Color(UIColor.label))
                                .lineSpacing(6)
                                .kerning(0.3)
                        }
                        if let attributed2 = try? AttributedString(markdown: localizedTextPart2) {
                            Text(attributed2)
                                .font(.montserrat(.bold, for: .caption))
                                .foregroundColor(Color(UIColor.label))
                                .lineSpacing(6)
                                .kerning(0.3)
                                .padding(.top, 4)
                        }
                    } else if #available(iOS 15.0, *) {
                        Text(localizedText)
                            .font(.montserrat(.medium, for: .caption))
                            .foregroundColor(Color(UIColor.label))
                        Text(localizedTextPart2)
                            .font(.montserrat(.bold, for: .caption))
                            .foregroundColor(Color(UIColor.label))
                            .padding(.top, 4)
                    } else {
                        Text(localizedText)
                            .font(.montserrat(.medium, for: .caption))
                            .foregroundColor(Color(UIColor.label))
                            .lineSpacing(6)
                        Text(localizedTextPart2)
                            .font(.montserrat(.bold, for: .caption))
                            .foregroundColor(Color(UIColor.label))
                            .lineSpacing(6)
                            .padding(.top, 4)
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
                            trackFeatureToggled(featureName: "proof_mode", enabled: true)
                            if !(URL.proofModePrivateKey?.exists ?? false) {
                                Proof.shared.initializeWithDefaultKeys()
                            }
                        }
                    } else if status == .denied || status == .restricted {
                        Settings.proofMode = false
                        isProofModeEnabled = false
                        trackFeatureToggled(featureName: "proof_mode", enabled: false)
                        showAlert = true
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Group {
                if showAlert {
                    Color.black.opacity(0.7)
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
                               
                        )
                }
            })
    }
    struct ProofModeView: View {
        var body: some View {
            Text(NSLocalizedString("ProofMode is a way to enhance the authentication and verification of multimedia content. ", comment: "ProofMode description"))
                .font(.montserrat(.medium, for: .caption))
                .foregroundColor(.primary)
            +
            Text("[\(NSLocalizedString("Learn more here.", comment: "Learn more link"))](https://proofmode.org)")
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

class LocationManangerProofMode: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationManangerProofMode()
    
    var status: CLAuthorizationStatus {
        LibProofMode.LocationManager.shared.authorizationStatus
    }
    
    private var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    private let observerManager = CLLocationManager()
    
    override private init() {
        super.init()
        observerManager.delegate = self
        observerManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuthorization(_ callback: ((_ status: CLAuthorizationStatus) -> Void)? = nil) {
        if status == .notDetermined {
            LibProofMode.LocationManager.shared.getPermission(callback: callback ?? { _ in })
        } else {
            callback?(status)
        }
    }
    
    func monitorAuthorizationChanges(_ callback: @escaping (CLAuthorizationStatus) -> Void) {
        onAuthorizationChange = callback
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

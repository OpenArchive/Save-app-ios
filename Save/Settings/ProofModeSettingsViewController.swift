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

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ToggleSwitch(
                title: NSLocalizedString("Enable ProofMode", comment: "Enable ProofMode"),
                subtitle: NSLocalizedString("Share ProofMode public key", comment: "Share ProofMode public key"),
                isOn: $isProofModeEnabled
            ) { value in
                handleProofModeToggle(value)
            }

            ProofModeView()

            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
                    .padding(.leading, 10)
                    .padding(.top, 16)
                
                VStack(alignment: .leading) {
                    
                    let localizedText = String(format: NSLocalizedString(
                              "ProofMode gathers metadata from local cell towers to help verify media. Android requires permission to enable this setting. %@ will only use this setting to capture data and will NOT access your phone to make/manage calls.",
                              comment: "Warning about ProofMode metadata"), "Save")
                    
                    if #available(iOS 15, *) {
                        Text(AttributedString.boldSubstring(in: localizedText, substring: "Save"))
                            .font(.montserrat(.medium, for: .caption2)).foregroundColor(.black)
                    } else {
                        if #available(iOS 16.0, *) {
                            Text(localizedText)
                                .font(.montserrat(.medium, for: .caption)).foregroundColor(.black).lineSpacing(6)
                                .kerning(0.3)
                        } else {
                            Text(localizedText)
                                .font(.montserrat(.medium, for: .caption)).foregroundColor(.black).lineSpacing(6)
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

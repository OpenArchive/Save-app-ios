//
//  CreateCCLView.swift
//  Save
//
//  Created by Claude Code on 2026-01-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI
import YapDatabase

@available(iOS 14.0, *)
struct CreateCCLView: View {
    static let ccUrl = "https://creativecommons.org/licenses/%@/4.0/"
    static let cc0Url = "https://creativecommons.org/publicdomain/zero/1.0/"
    static let ccMoreUrl = "https://creativecommons.org/about/cclicenses/"

    let space: Space
    var onNext: ((String) -> Void)?

    @State private var serverName: String = ""
    @State private var isCcEnabled: Bool = false
    @State private var isCc0Enabled: Bool = false
    @State private var allowRemix: Bool = false
    @State private var requireShareAlike: Bool = false
    @State private var allowCommercialUse: Bool = false
    @State private var licenseURL: String? = nil
    @State private var isKeyboardVisible: Bool = false

    private var isInternetArchive: Bool {
        space is IaSpace
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {

                    // Title
                    Text(isInternetArchive
                         ? NSLocalizedString("Choose a licence", comment: "")
                         : NSLocalizedString("Name your server and choose a licence", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.bottom,30)

                    // Server Name (only for Private Server)
                    if !isInternetArchive {
                        CustomTextField(
                            placeholder: NSLocalizedString("Server Name (Optional)", comment: ""),
                            text: $serverName,
                            isDisabled: false,
                            onEditingChanged: { isEditing in
                                isKeyboardVisible = isEditing
                            }
                        )
                        .padding(.bottom, 20)
                    }


                    // CC License Toggle
                    Toggle(NSLocalizedString("Set creative commons licenses for folders on this server.", comment: ""), isOn: $isCcEnabled)
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))
                        .onChange(of: isCcEnabled) { newValue in
                            if !newValue {
                                // Reset all when disabled
                                isCc0Enabled = false
                                allowRemix = false
                                requireShareAlike = false
                                allowCommercialUse = false
                            }
                            updateLicense()
                        }

                    // CC0 and other toggles (shown only when CC is enabled)
                    if isCcEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(NSLocalizedString("Waive all restrictions, requirements, and attribution (CC0).", comment: ""), isOn: $isCc0Enabled)
                                .toggleTint(.accent)
                                .font(.montserrat(.medium, for: .subheadline))
                                .onChange(of: isCc0Enabled) { newValue in
                                    if newValue {
                                        // CC0 disables other options
                                        allowRemix = false
                                        requireShareAlike = false
                                        allowCommercialUse = false
                                    }
                                    updateLicense()
                                }

                            Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: ""), isOn: $allowRemix)
                                .toggleTint(.accent)
                                .font(.montserrat(.medium, for: .subheadline))
                                .onChange(of: allowRemix) { newValue in
                                    if newValue && isCc0Enabled {
                                        isCc0Enabled = false
                                    }
                                    if !newValue {
                                        requireShareAlike = false
                                    }
                                    updateLicense()
                                }

                            Toggle(NSLocalizedString("Require them to share like you have?", comment: ""), isOn: $requireShareAlike)
                                .toggleTint(.accent)
                                .font(.montserrat(.medium, for: .subheadline))
                                .disabled(!allowRemix)
                                .onChange(of: requireShareAlike) { _ in
                                    if isCc0Enabled {
                                        isCc0Enabled = false
                                    }
                                    updateLicense()
                                }

                            Toggle(NSLocalizedString("Allow commercial use?", comment: ""), isOn: $allowCommercialUse)
                                .toggleTint(.accent)
                                .font(.montserrat(.medium, for: .subheadline))
                                .onChange(of: allowCommercialUse) { _ in
                                    if isCc0Enabled {
                                        isCc0Enabled = false
                                    }
                                    updateLicense()
                                }

                            // Display license URL
                            if let licenseURL = licenseURL, let url = URL(string: licenseURL) {
                                Text(AttributedString(licenseURL, attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                                    .foregroundColor(.accentColor)
                                    .font(.montserrat(.medium, for: .subheadline))
                                    .padding(.top, 5)
                                    .onTapGesture {
                                        UIApplication.shared.open(url)
                                    }
                            }
                        }
                        .padding(.top, 5)
                    }

                    // Learn More Link
                    if let learnMoreUrl =  URL(string: CreateCCLView.ccMoreUrl) {
                        Text(AttributedString(NSLocalizedString("Learn more about Creative Commons.", comment: ""), attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                            .foregroundColor(.accentColor)
                            .font(.montserrat(.medium, for: .subheadline))
                            .padding(.top, 10)
                            .onTapGesture {
                                UIApplication.shared.open(learnMoreUrl)
                            }
                    }

                    // Bottom padding to account for fixed button
                    Spacer()
                        .frame(height: 80)
                }
                .padding(.horizontal, 16)
            }
            
            // Fixed Next Button at bottom
            VStack {
                Button(action: {
                    saveLicense()
                    onNext?(serverName)
                }) {
                    Text(NSLocalizedString("Next", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.black)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(Color.accent)
                        .cornerRadius(10)
                }
                .frame(width: UIScreen.main.bounds.width / 2)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .offset(y: -70)
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize server name if space already has one
            serverName = space.name ?? ""
        }
    }

    // MARK: - License Logic

    private func updateLicense() {
        let license = getLicense()
        licenseURL = license
    }

    private func getLicense() -> String? {
        guard isCcEnabled else { return nil }

        if isCc0Enabled {
            return Self.cc0Url
        }

        var license = "by"

        if allowRemix {
            if !allowCommercialUse {
                license += "-nc"
            }
            if requireShareAlike {
                license += "-sa"
            }
        } else {
            if !allowCommercialUse {
                license += "-nc"
            }
            license += "-nd"
        }

        return String(format: Self.ccUrl, license)
    }

    private func saveLicense() {
        let license = getLicense()
        space.license = license

        // Save to database
        Db.writeConn?.asyncReadWrite { tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)

            // Update all active projects for this space
            let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }
            for project in projects {
                project.license = license
                tx.setObject(project)
            }
        }
    }
}


// MARK: - Preview

struct CreateCCLView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreateCCLView(space: IaSpace()) { serverName in
                print("Next tapped with name: \(serverName)")
            }
        }
    }
}

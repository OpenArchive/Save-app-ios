//
//  ServerSettingsView.swift
//  Save
//
//  Created by navoda on 2025-02-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
extension Notification.Name {
    static let privateServerSettingsConfirm = Notification.Name("privateServerSettingsConfirm")
}
@available(iOS 14.0, *)
struct PrivateServerSettingsView: View {
    static let ccUrl = "https://creativecommons.org/licenses/%@/4.0/"
    let ccMoreUrl = "https://creativecommons.org/about/cclicenses/"
    @StateObject private var store: ServerSettingsStore
    @State private var serverName: String
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var changetitle: ((String) -> Void)?
    var onEditingChanged: ((Bool) -> Void)?
    init(space: Space,disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil,changeTitle: ((String) -> Void)? = nil, onEditingChanged: ((Bool) -> Void)? = nil) {
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        self.changetitle = changeTitle
        self.onEditingChanged = onEditingChanged
        let isCC0 = space.license?.contains("publicdomain/zero") == true
        let initialState = ServerSettingsState(
            space:space,
            serverName: space.name ?? "",
            serverURL: space.url?.absoluteString ?? "",
            username: space.username ?? "",
            password: space.password != nil ? String(repeating: "•", count: space.password?.count ?? 0) : "",
            isCcEnabled: space.license != nil,
            isCc0Enabled: isCC0,
            allowRemix: isCC0 ? false : space.license?.contains("-nd") == false,
            requireShareAlike: isCC0 ? false : space.license?.contains("-sa") == true,
            allowCommercialUse: isCC0 ? false : space.license?.contains("-nc") == false,
            licenseURL: space.license
        )
        _serverName = State(initialValue: initialState.serverName)
        _store = StateObject(wrappedValue: ServerSettingsStore(initialState: initialState))
    }
    
    @State private var showDeleteAlert = false
    @State private var showSuccessAlert = false
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    
                    SectionHeader(title: NSLocalizedString("Server info",comment: ""))
                    
                    CustomTextField(
                        placeholder:NSLocalizedString( "Server URL",comment: ""),
                        text: .constant(store.state.serverURL),
                        isDisabled: true
                    )
                    CustomTextField(
                        placeholder: NSLocalizedString("Server Name",comment: ""),
                        text: $serverName,
                        isDisabled: false,
                        onEditingChanged: { began in
                            onEditingChanged?(began)
                        }, onCommit:  {
                            store.dispatch(action: .updateServerName(serverName))
                            store.dispatch(action: .saveToDatabase)
                            showSuccessAlert = true
                        })
                    
                    SectionHeader(title:NSLocalizedString( "Account",comment: ""))
                    
                    CustomTextField(
                        placeholder: NSLocalizedString("Username",comment: ""),
                        text: .constant(store.state.username),
                        isDisabled: true
                    )
                    
                    CustomTextField(
                        
                        placeholder:NSLocalizedString( "Password",comment: ""),
                        text: .constant(store.state.password),
                        isSecure: true, isDisabled: true
                        
                    )
                    
                    SectionHeader(title:NSLocalizedString( "License",comment: "" ))
                    
                    Toggle(NSLocalizedString("Set creative commons licenses for folders on this server.", comment: "Creative Commons Toggle"), isOn: Binding(
                        get: { store.state.isCcEnabled },
                        set: { newValue in
                            store.dispatch(action: .toggleCcEnabled(newValue))
                            store.dispatch(action: .updateLicense)
                        }
                    )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
                    
                    if store.state.isCcEnabled {
                        LicenseToggles(store: store)
                    }
                    
                    if  let url = URL(string: "https://creativecommons.org/") {
                        
                        Text(AttributedString(NSLocalizedString(NSLocalizedString("Learn more about Creative Commons.", comment: "More Info Link"), comment: "License Link"), attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                            .foregroundColor(.accentColor)
                            .font(.montserrat(.medium, for: .subheadline))
                            .padding(.top, 10)
                            .onTapGesture {
                                UIApplication.shared.open(url)
                            }
                        
                    }
                    
                    HStack {
                        Button(NSLocalizedString("Remove from app", comment: "Remove Button")) {
                            showDeleteAlert = true
                            disableBackAction?(true)
                        }
                        .foregroundColor(.redButton)
                        .padding(.top, 20).font(.montserrat(.semibold, for: .headline))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }.onReceive(NotificationCenter.default.publisher(for: Foundation.Notification.Name.privateServerSettingsConfirm)) { _ in
            store.dispatch(action: .updateServerName(serverName))
            store.dispatch(action: .saveToDatabase)
            showSuccessAlert = true
        }.overlay(
            Group {
                if showDeleteAlert {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Remove from app", comment: ""),
                                    message: NSLocalizedString("Are you sure you want to remove this server from the app?", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Remove", comment: ""),
                                    iconImage: Image("trash_icon"),
                                    primaryButtonAction: {
                                        store.dispatch(action: .removeSpace(store.state.space!))
                                        showDeleteAlert = false
                                        disableBackAction?(false)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            dismissAction?()
                                        }
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    secondaryButtonAction: {
                                        showDeleteAlert = false
                                        disableBackAction?(false)
                                    },
                                    showCheckbox: false, isRemoveAlert: true
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                }
                if showSuccessAlert {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Success!", comment: ""),
                                    message: NSLocalizedString("You have changed your server settings successfully.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                                    iconImage: Image("check_icon"),
                                    primaryButtonAction: {
                                        showSuccessAlert = false
                                        changetitle?(serverName)
                                    },
                                    showCheckbox: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                        )
                }
                
                
            })
        
    }}


// MARK: - License Toggles
struct LicenseToggles: View {
    @ObservedObject var store: ServerSettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(NSLocalizedString("Waive all restrictions, requirements, and attribution (CC0).", comment: "CC0 Toggle"), isOn: Binding(
                get: { store.state.isCc0Enabled },
                set: { newValue in
                    store.dispatch(action: .toggleCc0Enabled(newValue))
                    store.dispatch(action: .updateLicense)
                }
            ))
            .toggleTint(.accent)
            .font(.montserrat(.medium, for: .subheadline))
            
            Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: "Remix Toggle"), isOn: Binding(
                get: { store.state.allowRemix },
                set: { newValue in
                    store.dispatch(action: .toggleAllowRemix(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
            
            
            Toggle(NSLocalizedString("Require them to share like you have?", comment: "ShareAlike Toggle"), isOn: Binding(
                get: { store.state.requireShareAlike },
                set: { newValue in
                    store.dispatch(action: .toggleRequireShareAlike(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent)
                .disabled(!store.state.allowRemix).font(.montserrat(.medium, for: .subheadline))
            
            Toggle(NSLocalizedString("Allow commercial use?", comment: "Commercial Use Toggle"), isOn: Binding(
                get: { store.state.allowCommercialUse },
                set: { newValue in
                    store.dispatch(action: .toggleAllowCommercialUse(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
            
            if let licenseURL = store.state.licenseURL, let url = URL(string: licenseURL) {
                
                Text(AttributedString(NSLocalizedString(licenseURL, comment: "License Link"), attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                    .foregroundColor(.accentColor)
                    .font(.montserrat(.medium, for: .subheadline))
                    .padding(.top, 10)
                    .onTapGesture {
                        UIApplication.shared.open(url)
                    }
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    var title: String
    
    var body: some View {
        Text(NSLocalizedString(title, comment: "\(title) Section"))
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
            .padding(.top,20)
            .padding(.bottom,10)
    }
    
}

struct ToggleTintModifier: ViewModifier {
    var color: Color
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.tint(color) 
        } else {
            content.accentColor(color)
        }
    }
}


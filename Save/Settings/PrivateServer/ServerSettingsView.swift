//
//  ServerSettingsView.swift
//  Save
//
//  Created by navoda on 2025-02-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI

@available(iOS 14.0, *)
struct ServerSettingsView: View {
    static let ccUrl = "https://creativecommons.org/licenses/%@/4.0/"
    let ccMoreUrl = "https://creativecommons.org/about/cclicenses/"
    @StateObject private var store: ServerSettingsStore
    @State private var serverName: String
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var changetitle: ((String) -> Void)?
    init(space: Space,disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil,changeTitle: ((String) -> Void)? = nil) {
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        self.changetitle = changeTitle
        let initialState = ServerSettingsState(
            space:space,
            serverName: space.name ?? "",
            serverURL: space.url?.absoluteString ?? "",
            username: space.username ?? "",
            password: "••••••••", // Do not expose real password
            isCcEnabled: space.license != nil,
            allowRemix: space.license?.contains("-nd") == false,
            requireShareAlike: space.license?.contains("-sa") == true,
            allowCommercialUse: space.license?.contains("-nc") == false,
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
                        isDisabled: false, onCommit:  {
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
                    
                    Toggle(NSLocalizedString("Set creative commons licenses for folders on this server", comment: "Creative Commons Toggle"), isOn: Binding(
                        get: { store.state.isCcEnabled },
                        set: { newValue in
                            store.dispatch(action: .toggleCcEnabled(newValue))
                            store.dispatch(action: .updateLicense)
                        }
                    )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
                    
                    if store.state.isCcEnabled {
                        LicenseToggles(store: store)
                    }
                    if #available(iOS 14.0, *) {
                        Link(NSLocalizedString("Learn more about Creative Commons", comment: "More Info Link"), destination: URL(string: "https://creativecommons.org/")! )
                            .foregroundColor(.accentColor)
                            .padding(.top, 10).font(.montserrat(.medium, for: .subheadline))
                    } else {
                        
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
        }.overlay(
            Group {
                if showDeleteAlert {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Are you sure?", comment: ""),
                                    message: NSLocalizedString("Removing this server will delete all associated data.", comment: ""),
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
                                .background(Color.black.opacity(0.2))
                        )
                }
                if showSuccessAlert {
                    Color.gray.opacity(0.9)
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
                                .background(Color.black.opacity(0.2))
                        )
                }
                
                
            })
        
    }}


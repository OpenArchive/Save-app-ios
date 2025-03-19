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
                    
                    SectionHeader(title: "Server info")
                    
                    CustomTextField(
                        placeholder: "Server URL",
                        text: .constant(store.state.serverURL),
                        isDisabled: true
                    )
                    CustomTextField(
                        placeholder: "Server Name",
                        text: $serverName,
                        isDisabled: false, onCommit:  {
                            store.dispatch(action: .updateServerName(serverName))
                            store.dispatch(action: .saveToDatabase)
                            showSuccessAlert = true
                        })
                   
                    SectionHeader(title: "Account")
                    
                    CustomTextField(
                        placeholder: "Username",
                        text: .constant(store.state.username),
                        isDisabled: true
                    )
                    
                    CustomTextField(
                        
                        placeholder: "Password",
                        text: .constant(store.state.password),
                        isSecure: true, isDisabled: true
                        
                    )
                    
                    SectionHeader(title: "License")
                    
                    Toggle(NSLocalizedString("Set creative commons licenses for folders on this server", comment: "Creative Commons Toggle"), isOn: Binding(
                        get: { store.state.isCcEnabled },
                        set: { newValue in
                            store.dispatch(action: .toggleCcEnabled(newValue))
                            store.dispatch(action: .updateLicense)
                        }
                    )) .toggleTint(.accent).font(.menuMediumFont)
                    
                    if store.state.isCcEnabled {
                        LicenseToggles(store: store)
                    }
                    if #available(iOS 14.0, *) {
                        Link(NSLocalizedString("Learn more about Creative Commons", comment: "More Info Link"), destination: URL(string: "https://creativecommons.org/")! )
                            .foregroundColor(.accentColor)
                            .padding(.top, 10).font(.menuMediumFont)
                    } else {
                        
                    }

                    
                    
                    HStack {
                        Button(NSLocalizedString("Remove from app", comment: "Remove Button")) {
                            showDeleteAlert = true
                            disableBackAction?(true)
                        }
                        .foregroundColor(.redButton)
                        .padding(.top, 20).font(.headlineFont2)
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
                    Color.black.opacity(0.4)
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
                    Color.black.opacity(0.4)
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

   // MARK: - Custom TextField


struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    var onEditingChanged: (() -> Void)? = nil
    var onCommit: (() -> Void)? = nil
   

    var body: some View {
        Group {
            if isSecure {
                       SecureField(NSLocalizedString(placeholder, comment: "\(placeholder) Placeholder"), text: $text)
                   } else {
                       if #available(iOS 14.0, *) {
                           TextField(NSLocalizedString(placeholder, comment: "\(placeholder) Placeholder"), text: $text, onEditingChanged: { _ in
                               onEditingChanged?()
                           }, onCommit: {
                               onCommit?()
                           }).onChange(of: text) { newValue in
                               onEditingChanged?()
                           }
                       } else {
                           // Fallback on earlier versions
                       }
                   }
        }
        .padding(12)
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray70))
        .background(isDisabled ? Color.gray.opacity(0.2) : Color.textboxBg)
        .disabled(isDisabled)
        .padding(.bottom, 8)
        
    }
}

   // MARK: - License Toggles
   struct LicenseToggles: View {
       @ObservedObject var store: ServerSettingsStore

       var body: some View {
           VStack(alignment: .leading, spacing: 10) {
               Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: "Remix Toggle"), isOn: Binding(
                   get: { store.state.allowRemix },
                   set: { newValue in
                       store.dispatch(action: .toggleAllowRemix(newValue))
                       store.dispatch(action: .updateLicense)
                   }
               )) .toggleTint(.accent).font(.menuMediumFont)

               Toggle(NSLocalizedString("Require them to share like you have?", comment: "ShareAlike Toggle"), isOn: Binding(
                   get: { store.state.requireShareAlike },
                   set: { newValue in
                       store.dispatch(action: .toggleRequireShareAlike(newValue))
                       store.dispatch(action: .updateLicense)
                   }
               )) .toggleTint(.accent)
               .disabled(!store.state.allowRemix).font(.menuMediumFont)

               Toggle(NSLocalizedString("Allow commercial use?", comment: "Commercial Use Toggle"), isOn: Binding(
                   get: { store.state.allowCommercialUse },
                   set: { newValue in
                       store.dispatch(action: .toggleAllowCommercialUse(newValue))
                       store.dispatch(action: .updateLicense)
                   }
               )) .toggleTint(.accent).font(.menuMediumFont)
         
               if let licenseURL = store.state.licenseURL {
                   if #available(iOS 14.0, *) {
                       Link(NSLocalizedString(licenseURL, comment: "License Link"), destination: URL(string: licenseURL)!)
                           .foregroundColor(.accentColor)
                           .padding(.top, 10).font(.menuMediumFont)
                   } else {
                       // Fallback on earlier versions
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
               .font(.headlineFont2)
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

// MARK: - View Extension for Easy Usage
extension View {
    func toggleTint(_ color: Color) -> some View {
        self.modifier(ToggleTintModifier(color: color))
    }
}
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

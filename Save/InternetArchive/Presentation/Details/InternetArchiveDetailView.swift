//
//  InternetArchiveDetailView.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//
import SwiftUI

struct InternetArchiveDetailView : View {
    
    @ObservedObject var viewModel: InternetArchiveDetailViewModel
    
    var body: some View {
        InternetArchiveDetailContent(
            state: viewModel.store.dispatcher.state,
            dispatch: viewModel.store.dispatch
        )
    }
}

struct InternetArchiveDetailContent: View {
    
    let state: InternetArchiveDetailState
    let dispatch: Dispatch<InternetArchiveDetailAction>
    
    @State private var showAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Text(NSLocalizedString("Account", comment:""))
                    .font(.montserrat(.semibold, for: .headline))
                    .padding(.horizontal)
                
                Text(state.userName)
                    .font(.montserrat(.medium, for: .footnote))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundColor(.gray70)
                    .background(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray70, lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Text(state.screenName)
                    .font(.montserrat(.medium, for: .footnote))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray70)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray70, lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Text(state.email)
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(.gray70)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray70, lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                // MARK: License Section
                Text(NSLocalizedString("Licence", comment:""))
                    .font(.montserrat(.semibold, for: .headline))
                    .padding(.horizontal)
                    .padding(.top ,10)
                
                Toggle(
                    NSLocalizedString("Set creative commons licenses for folders on this server", comment: ""),
                    isOn: Binding(
                        get: { state.isCcEnabled },
                        set: { newValue in
                            dispatch(.toggleCcEnabled(newValue))
                            dispatch(.updateLicense)
                        }
                    )
                )
                .toggleTint(.accent)
                .font(.montserrat(.medium, for: .subheadline))
                .padding(.horizontal)
                
                if state.isCcEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: ""), isOn: Binding(
                            get: { state.allowRemix },
                            set: { newValue in
                                dispatch(.toggleAllowRemix(newValue))
                                dispatch(.updateLicense)
                            }
                        ))
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))
                        
                        Toggle(NSLocalizedString("Require them to share like you have?", comment: ""), isOn: Binding(
                            get: { state.requireShareAlike },
                            set: { newValue in
                                dispatch(.toggleRequireShareAlike(newValue))
                                dispatch(.updateLicense)
                            }
                        ))
                        .toggleTint(.accent)
                        .disabled(!state.allowRemix)
                        .font(.montserrat(.medium, for: .subheadline))
                        
                        Toggle(NSLocalizedString("Allow commercial use?", comment: ""), isOn: Binding(
                            get: { state.allowCommercialUse },
                            set: { newValue in
                                dispatch(.toggleAllowCommercialUse(newValue))
                                dispatch(.updateLicense)
                            }
                        ))
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))
                        
                        if let licenseURL = state.licenseURL {
                            if #available(iOS 14.0, *) {
                                Link(NSLocalizedString(licenseURL, comment: "License Link"), destination: URL(string: licenseURL)!)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 10)
                                    .font(.montserrat(.medium, for: .subheadline))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if #available(iOS 14.0, *) {
                    Link(NSLocalizedString("Learn more about Creative Commons", comment: "More Info Link"), destination: URL(string: "https://creativecommons.org/")! )
                        .foregroundColor(.accentColor)
                        .padding(.top, 10)
                        .padding(.horizontal) 
                        .font(.montserrat(.medium, for: .subheadline))
                }
                
                // MARK: Remove Button
                HStack {
                    Spacer()
                    Button(action: {
                        showAlert = true
                        dispatch(.HandleBackButton(status: true))
                    }) {
                        Text(LocalizedStringKey("Remove from App"))
                            .font(.montserrat(.semibold, for: .headline))
                            .foregroundColor(.redButton)
                            .padding()
                    }
                    Spacer()
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.top, 30)
        }
        .overlay(
            Group {
                if showAlert {
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
                                        dispatch(.Remove)
                                        showAlert = false
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    secondaryButtonAction: {
                                        showAlert = false
                                        dispatch(.HandleBackButton(status: false))
                                    },
                                    showCheckbox: false,
                                    isRemoveAlert: true
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.2))
                        )
                }
            }
        )
    }
}


struct InternetArchiveDetailView_Previews: PreviewProvider {
    static let state = InternetArchiveDetailState(
        screenName: "ABC User",
        userName: "@abc_user1",
        email: "abc@example.com"
    )
    
    static var previews: some View {
        InternetArchiveDetailContent(state: state) { _ in }
    }
}

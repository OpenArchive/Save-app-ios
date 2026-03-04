//
//  InternetArchiveDetailView.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//
import SwiftUI

struct InternetArchiveDetailView: View {

    @ObservedObject var viewModel: InternetArchiveDetailViewModel

    var body: some View {
        InternetArchiveDetailContent(viewModel: viewModel)
    }
}

struct InternetArchiveDetailContent: View {

    @ObservedObject var viewModel: InternetArchiveDetailViewModel
    @State private var showAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text(NSLocalizedString("Account", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
                    .padding(.horizontal)

                Text(viewModel.userName)
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

                Text(viewModel.screenName)
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

                Text(viewModel.email)
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

                Text(NSLocalizedString("License", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
                    .padding(.horizontal)
                    .padding(.top, 10)

                Toggle(
                    NSLocalizedString("Set creative commons licenses for folders on this server.", comment: ""),
                    isOn: Binding(
                        get: { viewModel.isCcEnabled },
                        set: { viewModel.toggleCcEnabled($0) }
                    )
                )
                .toggleTint(.accent)
                .font(.montserrat(.medium, for: .subheadline))
                .padding(.horizontal)

                if viewModel.isCcEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(NSLocalizedString("Waive all restrictions, requirements, and attribution (CC0).", comment: "CC0 Toggle"), isOn: Binding(
                            get: { viewModel.isCc0Enabled },
                            set: { viewModel.toggleCc0Enabled($0) }
                        ))
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))
                        Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: ""), isOn: Binding(
                            get: { viewModel.allowRemix },
                            set: { viewModel.toggleAllowRemix($0) }
                        ))
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))

                        Toggle(NSLocalizedString("Require them to share like you have?", comment: ""), isOn: Binding(
                            get: { viewModel.requireShareAlike },
                            set: { viewModel.toggleRequireShareAlike($0) }
                        ))
                        .toggleTint(.accent)
                        .disabled(!viewModel.allowRemix)
                        .font(.montserrat(.medium, for: .subheadline))

                        Toggle(NSLocalizedString("Allow commercial use?", comment: ""), isOn: Binding(
                            get: { viewModel.allowCommercialUse },
                            set: { viewModel.toggleAllowCommercialUse($0) }
                        ))
                        .toggleTint(.accent)
                        .font(.montserrat(.medium, for: .subheadline))

                        if let licenseURL = viewModel.licenseURL, let url = URL(string: licenseURL) {
                            Text(AttributedString(licenseURL, attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                                .foregroundColor(.accentColor)
                                .font(.montserrat(.medium, for: .subheadline))
                                .padding(.top, 10)
                                .onTapGesture {
                                    UIApplication.shared.open(url)
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                if let url = URL(string: "https://creativecommons.org/") {
                    Text(AttributedString(NSLocalizedString(NSLocalizedString("Learn more about Creative Commons.", comment: "More Info Link"), comment: "License Link"), attributes: AttributeContainer([.underlineStyle: NSUnderlineStyle.single.rawValue])))
                        .foregroundColor(.accentColor)
                        .font(.montserrat(.medium, for: .subheadline))
                        .padding(.top, 10)
                        .onTapGesture {
                            UIApplication.shared.open(url)
                        }
                        .padding(.horizontal)
                }

                HStack {
                    Spacer()
                    Button(action: {
                        showAlert = true
                        viewModel.setBackButtonVisibility(true)
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
                                        viewModel.removeSpace()
                                        showAlert = false
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonIsOutlined: false,
                                    secondaryButtonAction: {
                                        showAlert = false
                                        viewModel.setBackButtonVisibility(false)
                                    },
                                    showCheckbox: false,
                                    isRemoveAlert: true
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                }
            }
        )
    }
}

// MARK: - Preview (uses state struct for static preview data)
struct InternetArchiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let space = IaSpace()
        let viewModel = InternetArchiveDetailViewModel(space: space)
        // Set preview data
        viewModel.userName = "@abc_user1"
        viewModel.screenName = "ABC User"
        viewModel.email = "abc@example.com"
        
        return InternetArchiveDetailContent(viewModel: viewModel)
    }
}


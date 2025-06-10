//
//  CreateFolderView.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//
import SwiftUI

// MARK: - SwiftUI View
struct CreateFolderView: View {
    @ObservedObject var store: NewFolderStore
    @State var folderName: String = ""
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    init(disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil) {
        
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        _folderName = .init(initialValue: "")
        _store = .init(wrappedValue: NewFolderStore())
        
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .center, spacing: 10) {
                    Text(NSLocalizedString("First, please name your folder", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("This folder will be created on your server and automatically added on Save.", comment: ""))
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(.gray70)
                        .multilineTextAlignment(.center).padding(.bottom,30)
                    
                    CustomTextField(
                        placeholder: NSLocalizedString("Enter folder name", comment: ""),
                        text: $folderName,
                        isDisabled: false,
                        onEditingChanged: {
                            store.dispatch(action: .updateFolderName(folderName))
                        }
                    )
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    store.dispatch(action: .updateFolderName(""))
                    dismissAction?()
                    
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)
                .padding()
                .font(.montserrat(.semibold, for: .headline))
                .cornerRadius(8)
                
                Button(NSLocalizedString("Create", comment: "")) {
                    disableBackAction?(true)
                    store.dispatch(action: .saveFolderName)
                    
                }
                .frame(maxWidth: .infinity)
                .padding()
                .font(.montserrat(.semibold, for: .headline))
                .background(store.state.folderName.isEmpty ? Color.gray50 : Color.accentColor)
                .foregroundColor(.black)
                .cornerRadius(8)
                .disabled(store.state.folderName.isEmpty)
            }
            .padding(.horizontal,20)
            .padding(.bottom, 20)
            
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 52)
        .overlay(
            Group {
                if store.state.status {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Success!", comment: ""),
                                    message: NSLocalizedString("You have added a folder successfully.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                                    iconImage: Image("check_icon"),
                                    primaryButtonAction: {
                                        store.dispatch(action: .resetStatus)
                                        disableBackAction?(false)
                                        dismissAction?()
                                    },
                                    showCheckbox: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
                if (store.state.errorMessage != nil) {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Error!", comment: ""),
                                    message: store.state.errorMessage ?? "",
                                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                                    iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                                    iconTint:.gray,
                                    primaryButtonAction: {
                                        disableBackAction?(false)
                                        store.dispatch(action: .resetStatus)
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
    }
    
}


//
//  EditFolderView.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

// MARK: - SwiftUI View
@available(iOS 14.0, *)
struct EditFolderView: View {
    @StateObject private var store:  EditFolderStore
    @State private var folderName: String
    @State private var showDeleteAlert: Bool
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var changeName: ((String) -> Void)?
    init(project: Project?,disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil,changeName: ((String) -> Void)? = nil) {
        
        let initialState = EditFolderState(
            project: project, folderName: project?.name ?? "", status: false, errorMessage: nil
            
        )
        self.changeName = changeName
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        _folderName = State(initialValue: initialState.folderName)
        _store = StateObject(wrappedValue: EditFolderStore(initialState: initialState))
        _showDeleteAlert = State(initialValue: false)
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("Folder Name", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .multilineTextAlignment(.leading)
                    
                    CustomTextField(
                        placeholder: "",
                        text: $folderName,
                        isDisabled: (!(store.state.project?.active ?? false) ),
                        onEditingChanged: {
                            store.dispatch(action: .updateFolderName(folderName))
                        },onCommit: {
                            store.dispatch(action:.saveFolderName)
                            changeName?(folderName)
                            disableBackAction?(true)
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.bottom,40)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button((store.state.project?.active ?? false) ? NSLocalizedString("Archive Project", comment: "") :  NSLocalizedString("Unarchive Project", comment: "")) {
                    store.dispatch(action:.archiveFolder)
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)
                .padding(.bottom,20)
                .font(.montserrat(.semibold, for: .headline))
                .cornerRadius(8)
                
                Button(NSLocalizedString("Remove from app", comment: "")) {
                    showDeleteAlert = true
                    disableBackAction?(true)
                    
                }
                .frame(maxWidth: .infinity)
                .font(.montserrat(.semibold, for: .headline))
                .foregroundColor(.redButton)
                .cornerRadius(8)
            }
            
            
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 52)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(
            Group {
                if store.state.status {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Success!", comment: ""),
                                    message: NSLocalizedString("You have renamed folder successfully.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                                    iconImage: Image("check_icon"),
                                    primaryButtonAction: {
                                        store.dispatch(action: .resetStatus)
                                        disableBackAction?(false)
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
                                        store.dispatch(action: .resetStatus)
                                        disableBackAction?(false)
                                    },
                                    showCheckbox: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                        )
                }
                if (showDeleteAlert) {
                    Color.gray.opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Are you sure?", comment: ""),
                                    message: String(format: NSLocalizedString(
                                        "Removing this folder will remove all contained thumbnails from the %@ app.",
                                        comment: "Placeholder is app name"), Bundle.main.displayName),
                                    primaryButtonTitle: NSLocalizedString("Remove", comment: ""),
                                    iconImage: Image("trash_icon"),
                                    iconTint:.gray,
                                    primaryButtonAction: {
                                        showDeleteAlert = false
                                        store.dispatch(action: .deleteFolder)
                                        dismissAction?()
                                    },
                                    secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                                    secondaryButtonAction: {
                                        disableBackAction?(false)
                                        showDeleteAlert = false
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
            })
    }
    
}


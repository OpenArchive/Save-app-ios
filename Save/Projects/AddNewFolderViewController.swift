//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

// Hosting: `AddNewFolderHostingController` in `FolderFlowHostingControllers.swift`.

struct AppState {
    var folderName: String = ""
    var status: Bool = false
    var errorMessage: String?
}

final class NewFolderStore: ObservableObject {

    @Published private(set) var state = AppState()

    func updateFolderName(_ name: String) {
        state.folderName = name
    }

    func saveFolderName() {
        let project = Project(space: SelectedSpace.space)
        guard let spaceId = project.spaceId else { return }

        let alert = DuplicateFolderAlert(nil)
        if alert.exists(spaceId: spaceId, name: state.folderName) {
            state.status = false
            state.errorMessage = NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: "")
        } else {
            state.status = true
            project.name = state.folderName
            Db.writeConn?.setObject(project)
            SelectedProject.project = project
            SelectedProject.store()
        }
    }

    func resetStatus() {
        state.status = false
        state.errorMessage = nil
    }
}


// MARK: - SwiftUI View
struct CreateFolderView: View {
    @StateObject var store: NewFolderStore
    @State var folderName: String = ""
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    init(disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil) {
    
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        _folderName = .init(initialValue: "")
        _store = StateObject(wrappedValue: NewFolderStore())
      
    }
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .center, spacing: 10) {
                    Text(NSLocalizedString("Please name your folder", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("This folder will be created on your server and added to Save.", comment: ""))
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(.gray70)
                        .multilineTextAlignment(.center).padding(.bottom,30)
                    
                    CustomTextField(
                        placeholder: NSLocalizedString("Enter folder name", comment: ""),
                        text: $folderName,
                        isDisabled: false,
                        onTextChanged:  { text  in
                            store.updateFolderName(text)
                        }
                    )
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    store.updateFolderName("")
                    dismissAction?()
                  
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.primary)
                .padding()
                .font(.montserrat(.semibold, for: .headline))
                .cornerRadius(8)
                Button(action: {
                    hideKeyboard()
                    disableBackAction?(true)
                    store.saveFolderName()
                }, label: {
                    Text(NSLocalizedString("Create",comment: "")).frame(maxWidth: .infinity)
                })
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
        .onTapGesture {
            hideKeyboard()
        }
        .overlay(
            Group {
                if store.state.status {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Success!", comment: ""),
                                    message: NSLocalizedString("You have added a folder successfully.", comment: ""),
                                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                                    iconImage: Image("check_icon"),
                                    primaryButtonAction: {
                                        store.resetStatus()
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
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Error", comment: ""),
                                    message: store.state.errorMessage ?? "",
                                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                                    iconImage: Image("ic_error"),
                                    iconTint:.gray,
                                    primaryButtonAction: {
                                        disableBackAction?(false)
                                        store.resetStatus()
                                    },
                                    showCheckbox: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                }
            })
    }
    private func hideKeyboard() {
           UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
       }
}


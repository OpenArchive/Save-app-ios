//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

class EditFolderViewController: UIViewController {
    var project: Project

    init(_ project: Project) {
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = project.name
            
            
            let editFolderView = EditFolderView(project: project,disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }, dismissAction: {
                
                self.navigationController?.popViewController(animated: true)
            },changeName: { [weak self] name in
                self?.title = name
            })
            
            let hostingController = UIHostingController(rootView: editFolderView)
            addChild(hostingController)
            view.addSubview(hostingController.view)
            
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hostingController.didMove(toParent: self)
            self.view.backgroundColor = .systemBackground
        }
    }
}

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
                    Text("Folder Name")
                        .font(.montserrat(.semibold, for: .headline))
                        .multilineTextAlignment(.leading)
                    
                    CustomTextField(
                        placeholder: "",
                        text: $folderName,
                        isDisabled: (!(store.state.project?.active ?? false) ),
                        onTextChanged: {text in
                            store.dispatch(action: .updateFolderName(text))
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
                    if (store.state.project?.active ?? false) {
                           dismissAction?()
                       }
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
                    Color.black.opacity(0.7)
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
                                        store.dispatch(action: .resetStatus)
                                        disableBackAction?(false)
                                    },
                                    showCheckbox: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                
                            }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                }
                if (showDeleteAlert) {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            VStack {
                                CustomAlertView(
                                    title: NSLocalizedString("Remove from app", comment: ""),
                                    message: String(format: NSLocalizedString(
                                        "Are you sure you want to remove your project?",
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
                               
                        )
                }
            })
    }
    
}





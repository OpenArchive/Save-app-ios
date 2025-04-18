//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

class NewEditFolderViewController: UIViewController {
    var project: Project
    
    
    // MARK: - Initializers
    
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



// MARK: - State
struct EditFolderState {
    var project:Project?
    var folderName: String = ""
    var status:Bool = false
    var errorMessage: String?
}

// MARK: - Actions
enum EditFolderAction {
    case updateFolderName(String)
    case saveFolderName
    case resetStatus
    case archiveFolder
    case deleteFolder
}

// MARK: - Reducer
func editAppReducer(state: inout EditFolderState, action: EditFolderAction) {
    switch action {
    case .updateFolderName(let name):
        state.folderName = name
    case .saveFolderName:
        editFolderName(state:&state)
    case .resetStatus:
        resetEditStatus(state:&state)
    case .archiveFolder:
        changeArchiveStatus(state:&state)
    case .deleteFolder:
        removeFolder(state:&state)
    }
}
func editFolderName(state:inout EditFolderState) {
    
    if let currentProject = state.project {
        
        let isExsists =  Db.bgRwConn?.find(where: { (project:Project) in
            project.spaceId == currentProject.spaceId && project.name == state.folderName && project.id != currentProject.id
        }) != nil
        
        if (isExsists){
            state.status = false
            state.errorMessage = NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: "")
        }else{
            state.status = true
            currentProject.name = state.folderName
            Db.writeConn?.setObject(currentProject)
        }
    }}
func removeFolder(state:inout EditFolderState) {
    
    if let currentProject = state.project {
        Db.writeConn?.asyncReadWrite() { tx in
            tx.remove(currentProject)}
    }}
func changeArchiveStatus(state:inout EditFolderState) {
    state.project?.active.toggle()
    if (state.project?.active ?? false), let license = SelectedSpace.space?.license {
        state.project?.license = license
    }
    if let project = state.project {
        Db.writeConn?.setObject(project)
    }
    
}
func resetEditStatus(state:inout EditFolderState) {
    state.status = false
    state.errorMessage = nil
}

// MARK: - Store
class EditFolderStore: ObservableObject {
    @Published private(set) var state = EditFolderState()
    
    init(initialState: EditFolderState) {
        self.state = initialState
    }
    func dispatch(action: EditFolderAction) {
        editAppReducer(state: &state, action: action)
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


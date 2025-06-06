//
//  AddNewFolderViewController.swift
//  Save
//
//  Created by navoda on 2025-03-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import UIKit

class AddNewFolderViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        
        if #available(iOS 14.0, *) {
            navigationItem.title = NSLocalizedString("Create a New Folder", comment: "")
        
            let settingsView = CreateFolderView(disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }, dismissAction: {
              
                if let navigationController = self.navigationController {
                    
                    if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {
                        
                        navigationController.popToViewController(existingVC, animated: true)
                    } else {
                        
                        let newVC = MainViewController()
                        navigationController.pushViewController(newVC, animated: true)
                    }
                }
            })
            
            let hostingController = UIHostingController(rootView: settingsView)
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
            self.view.backgroundColor = UIColor.systemBackground
        }
    }
}



// MARK: - State
struct AppState {
    var folderName: String = ""
    var status:Bool = false
    var errorMessage: String?
}

// MARK: - Actions
enum AppAction {
    case updateFolderName(String)
    case saveFolderName
    case resetStatus
}

// MARK: - Reducer
func appReducer(state: inout AppState, action: AppAction) {
    switch action {
    case .updateFolderName(let name):
        state.folderName = name
    case .saveFolderName:
        saveFolderName(state:&state)
    case .resetStatus:
        resetStatus(state:&state)
    }
}
func saveFolderName(state:inout AppState) {
    let project = Project(space: SelectedSpace.space)
    if let spaceId = project.spaceId {
        
        let alert = DuplicateFolderAlert(nil)
        if alert.exists(spaceId: spaceId, name: state.folderName){
            state.status = false
            state.errorMessage = NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: "")
        }
        else{
            state.status = true
            project.name = state.folderName
            Db.writeConn?.setObject(project)
        }
    }
}
func resetStatus(state:inout AppState) {
    state.status = false
    state.errorMessage = nil
}

// MARK: - Store
class NewFolderStore: ObservableObject {
    @Published private(set) var state = AppState()
    
    func dispatch(action: AppAction) {
        appReducer(state: &state, action: action)
    }
}


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


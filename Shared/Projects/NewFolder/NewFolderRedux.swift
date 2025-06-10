//
//  AppState.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

// MARK: - Store
class NewFolderStore: ObservableObject {
    @Published private(set) var state = AppState()
    
    func dispatch(action: AppAction) {
        appReducer(state: &state, action: action)
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


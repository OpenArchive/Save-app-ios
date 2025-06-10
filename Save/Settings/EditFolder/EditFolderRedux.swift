//
//  EditFolderState.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

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

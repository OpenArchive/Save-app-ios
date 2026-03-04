//
//  EditFolderState.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation

struct EditFolderState {
    var project: Project?
    var folderName: String = ""
    var status: Bool = false
    var errorMessage: String?
}

final class EditFolderStore: ObservableObject {

    @Published private(set) var state: EditFolderState

    init(initialState: EditFolderState) {
        self.state = initialState
    }

    func updateFolderName(_ name: String) {
        state.folderName = name
    }

    func saveFolderName() {
        guard let currentProject = state.project else { return }

        let exists = Db.bgRwConn?.find(where: { (project: Project) in
            let matchesSpace = project.spaceId == currentProject.spaceId
            let matchesName = project.name == state.folderName
            let isDifferentProject = project.id != currentProject.id
            return matchesSpace && matchesName && isDifferentProject
        }) != nil

        if exists {
            state.status = false
            state.errorMessage = NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: "")
        } else {
            state.status = true
            currentProject.name = state.folderName
            Db.writeConn?.setObject(currentProject)
        }
    }

    func resetStatus() {
        state.status = false
        state.errorMessage = nil
    }

    func archiveFolder() {
        state.project?.active.toggle()
        if state.project?.active == true, let license = SelectedSpace.space?.license {
            state.project?.license = license
        }
        if let project = state.project {
            Db.writeConn?.setObject(project)
        }
    }

    func deleteFolder() {
        if let currentProject = state.project {
            Db.writeConn?.asyncReadWrite { tx in
                tx.remove(currentProject)
            }
        }
    }
}

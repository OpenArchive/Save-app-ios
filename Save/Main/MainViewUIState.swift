//
//  MainViewUIState.swift
//  Save
//

import Foundation

@MainActor
final class MainViewUIState: ObservableObject {
    @Published var isRenameVisible = false
    @Published var isSelectMediaVisible = false
    @Published var isSettingsVisible = false
    @Published var isFolderMenuVisible = false
    @Published var renameText = ""
}

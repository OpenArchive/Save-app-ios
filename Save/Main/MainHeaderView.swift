//
//  MainHeaderView.swift
//  Save
//

import SwiftUI

struct MainHeaderView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var mediaGridViewModel: MediaGridViewModel
    @ObservedObject var uiState: MainViewUIState

    let folderAssetCountText: String
    let onStartRename: () -> Void
    let onSubmitRename: () -> Void
    let onCloseRename: () -> Void
    let onStartSelectMedia: () -> Void
    let onCloseSelectMedia: () -> Void
    let onRemoveAssets: () -> Void
    let onArchiveFolder: () -> Void
    let onRemoveFolder: () -> Void

    var body: some View {
        Group {
            if uiState.isRenameVisible {
                renameBar
            } else if uiState.isSelectMediaVisible {
                selectMediaBar
            } else {
                defaultBar
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }

    private var hasFolder: Bool {
        homeViewModel.selectedProjectId != nil
    }

    private var defaultBar: some View {
        HStack(spacing: 0) {
            if !homeViewModel.currentSpaceIcon.isEmpty {
                Image(homeViewModel.currentSpaceIcon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(.label))
                    .frame(width: 24, height: 24)
            }

            if hasFolder {
                Image("folder_arrow")
                    .renderingMode(.template)
                    .foregroundColor(Color(.label))
                    .frame(width: 24, height: 24)

                Text(homeViewModel.selectedProject?.name ?? "")
                    .font(.montserrat(.semibold, for: .body))
                    .foregroundColor(Color(.label))
                    .lineLimit(2)
                    .padding(.leading, 2)
            }

            Spacer(minLength: 8)

            if hasFolder {
                Button(action: { uiState.isFolderMenuVisible = true }) {
                    Image("edit_menu")
                        .renderingMode(.template)
                        .foregroundColor(Color(.label))
                        .frame(width: 24, height: 24)
                }
                .confirmationDialog(
                    "",
                    isPresented: $uiState.isFolderMenuVisible,
                    titleVisibility: .hidden
                ) {
                    Button(NSLocalizedString("Rename folder", comment: ""), action: onStartRename)
                    Button(NSLocalizedString("Select media", comment: ""), action: onStartSelectMedia)
                        .disabled(mediaGridViewModel.totalItemCount == 0)
                    Button(NSLocalizedString("Archive folder", comment: ""), action: onArchiveFolder)
                    Button(NSLocalizedString("Remove folder from app", comment: ""), role: .destructive, action: onRemoveFolder)
                    Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
                }

                Text(folderAssetCountText)
                    .font(.montserrat(.regular, for: .caption))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color("pill-background"))
                    )
                    .padding(.leading, 8)
            }
        }
    }

    private var renameBar: some View {
        HStack(spacing: 8) {
            Button(action: onCloseRename) {
                Image("close")
                    .renderingMode(.template)
                    .foregroundColor(Color(.label))
            }
            .frame(width: 24, height: 24)

            TextField("", text: $uiState.renameText)
                .font(.montserrat(.regular, for: .body))
                .submitLabel(.done)
                .onSubmit(onSubmitRename)
        }
    }

    private var selectMediaBar: some View {
        HStack(spacing: 8) {
            Button(action: onCloseSelectMedia) {
                Image("close")
                    .renderingMode(.template)
                    .foregroundColor(Color(.label))
            }
            .frame(width: 24, height: 24)

            Text(NSLocalizedString("Select Media", comment: ""))
                .font(.montserrat(.semibold, for: .body))

            Spacer()

            if mediaGridViewModel.hasSelection {
                Button(action: onRemoveAssets) {
                    Label(NSLocalizedString("Remove", comment: ""), systemImage: "trash")
                        .foregroundColor(Color("red-button")).font(.montserrat(.semibold, for: .body))
                }
            }
        }
    }
}

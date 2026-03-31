//
//  MainView.swift
//  Save
//

import SwiftUI

struct MainView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var mediaGridViewModel: MediaGridViewModel
    @ObservedObject var uiState: MainViewUIState

    let folderAssetCountText: String
    let onTapAdd: () -> Void
    let onLongPressAdd: () -> Void
    let onTapSettings: () -> Void
    let onTapMedia: () -> Void
    let onSelectAsset: (Asset) -> Void
    let onLongPressAsset: () -> Void
    let onTapAssetWithUpload: (Asset, Upload?) -> Void
    let onStartRename: () -> Void
    let onSubmitRename: () -> Void
    let onCloseRename: () -> Void
    let onStartSelectMedia: () -> Void
    let onCloseSelectMedia: () -> Void
    let onRemoveAssets: () -> Void
    let onArchiveFolder: () -> Void
    let onRemoveFolder: () -> Void
    let onHideMenu: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                if shouldShowHeader {
                    MainHeaderView(
                        homeViewModel: homeViewModel,
                        mediaGridViewModel: mediaGridViewModel,
                        uiState: uiState,
                        folderAssetCountText: folderAssetCountText,
                        onStartRename: onStartRename,
                        onSubmitRename: onSubmitRename,
                        onCloseRename: onCloseRename,
                        onStartSelectMedia: onStartSelectMedia,
                        onCloseSelectMedia: onCloseSelectMedia,
                        onRemoveAssets: onRemoveAssets,
                        onArchiveFolder: onArchiveFolder,
                        onRemoveFolder: onRemoveFolder
                    )
                }

                if homeViewModel.selectedProjectId != nil &&
                    (!mediaGridViewModel.sections.isEmpty || mediaGridViewModel.isRefreshing) {
                    MediaGridView(
                        viewModel: mediaGridViewModel,
                        onSelectAsset: onSelectAsset,
                        onLongPress: onLongPressAsset,
                        onTapAssetWithUpload: onTapAssetWithUpload
                    )
                } else {
                    WelcomeView(
                        hintText: welcomeHint,
                        showWelcomeTitle: !hasSpace
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainBottomMenuView(
                    isSettingsVisible: uiState.isSettingsVisible,
                    onTapMedia: onTapMedia,
                    onTapAdd: onTapAdd,
                    onLongPressAdd: onLongPressAdd,
                    onTapSettings: onTapSettings
                )
            }

            if homeViewModel.isMenuVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onHideMenu)
            }

            if homeViewModel.isMenuVisible {
                SideMenuView()
                    .environmentObject(homeViewModel)
                    .environmentObject(homeViewModel.coordinator)
                    .frame(width: UIScreen.main.bounds.width * 0.82)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: homeViewModel.isMenuVisible)
    }

    private var hasSpace: Bool {
        !homeViewModel.spaces.isEmpty
    }

    private var shouldShowHeader: Bool {
        hasSpace
    }

    private var welcomeHint: String {
        if !hasSpace {
            return NSLocalizedString("Tap the button below to add a server", comment: "")
        }
        if homeViewModel.selectedProjectId == nil {
            return NSLocalizedString("Tap the button below to add a folder", comment: "")
        }
        return NSLocalizedString("Tap the button below to add media", comment: "")
    }
}


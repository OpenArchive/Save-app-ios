//
//  MainView.swift
//  Save
//

import SwiftUI

struct MainView: View {
    let homeViewModel: HomeViewModel
    let mediaGridViewModel: MediaGridViewModel
    let uiState: MainViewUIState
    let settingsViewModel: SettingsViewModel

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
    let onTapMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MainTopNavigationBar(
                homeViewModel: homeViewModel,
                uiState: uiState,
                onMenuTap: onTapMenu
            )

            ZStack(alignment: .trailing) {
                MainCentralColumn(
                    homeViewModel: homeViewModel,
                    mediaGridViewModel: mediaGridViewModel,
                    uiState: uiState,
                    settingsViewModel: settingsViewModel,
                    folderAssetCountText: folderAssetCountText,
                    onTapAdd: onTapAdd,
                    onLongPressAdd: onLongPressAdd,
                    onTapSettings: onTapSettings,
                    onTapMedia: onTapMedia,
                    onSelectAsset: onSelectAsset,
                    onLongPressAsset: onLongPressAsset,
                    onTapAssetWithUpload: onTapAssetWithUpload,
                    onStartRename: onStartRename,
                    onSubmitRename: onSubmitRename,
                    onCloseRename: onCloseRename,
                    onStartSelectMedia: onStartSelectMedia,
                    onCloseSelectMedia: onCloseSelectMedia,
                    onRemoveAssets: onRemoveAssets,
                    onArchiveFolder: onArchiveFolder,
                    onRemoveFolder: onRemoveFolder
                )

                MainSideMenuPanel(homeViewModel: homeViewModel)
                    .environmentObject(homeViewModel.coordinator)
            }
        }
        .overlay {
            MainAlertToastOverlay()
        }
    }
}

// MARK: - Subviews (narrow observation: alerts/toasts vs shell vs grid)

private struct MainCentralColumn: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var mediaGridViewModel: MediaGridViewModel
    @ObservedObject var uiState: MainViewUIState
    @ObservedObject var settingsViewModel: SettingsViewModel

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

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowHeader && !uiState.isSettingsVisible {
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

            if uiState.isSettingsVisible {
                if #available(iOS 14.0, *) {
                    SettingsView()
                        .environmentObject(settingsViewModel)
                }
            } else if homeViewModel.selectedProjectId != nil &&
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
    }
}

private struct MainSideMenuPanel: View {
    @ObservedObject var homeViewModel: HomeViewModel

    var body: some View {
        Group {
            if homeViewModel.isMenuVisible {
                // Full-width overlay so the scrim covers the main column; panel width stays `HomeState.menuWidth` inside `SideMenuView`.
                SideMenuView()
                    .environmentObject(homeViewModel)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: homeViewModel.isMenuVisible)
    }
}

private struct MainAlertToastOverlay: View {
    @ObservedObject private var appOverlay = AppOverlayState.shared

    var body: some View {
        ZStack {
            if let presentation = appOverlay.activePresentation {
                CustomAlertFullScreenView(model: presentation) {
                    appOverlay.dismiss()
                }
                .transition(.opacity)
            }
            if let toast = appOverlay.toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: toast)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: appOverlay.toastMessage)
            }
        }
    }
}


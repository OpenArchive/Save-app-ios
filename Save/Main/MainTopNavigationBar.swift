//
//  MainTopNavigationBar.swift
//  Save
//

import SwiftUI

/// Teal top bar matching the former `UINavigationBar` styling (logo + menu).
struct MainTopNavigationBar: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var uiState: MainViewUIState

    let onMenuTap: () -> Void

    private var showMenuButton: Bool {
        !uiState.isSettingsVisible && !homeViewModel.spaces.isEmpty
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image("save_logo_navbar")
                .renderingMode(.original)
                .accessibilityLabel("Save")

            Spacer(minLength: 0)

            if showMenuButton {
                Button(action: onMenuTap) {
                    Image("menu_icon")
                        .renderingMode(.template)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btMenu")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background {
            Color("menu-background")
                .ignoresSafeArea(edges: [.top, .horizontal])
        }
    }
}

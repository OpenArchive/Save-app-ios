//
//  StyledButton.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI
import Combine

struct StyledButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    let isDisabled: Bool
    
    init(title: String, subtitle: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(isDisabled ? .gray50 : Color(.label))
                    Text(subtitle)
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(isDisabled ? .gray50 : .gray70)
                }
                Spacer()
                Image(uiImage: (UIImage(named: "forward_arrow")?.withRenderingMode(.alwaysTemplate))!)
                    .foregroundColor(isDisabled ? .gray50 : Color(.label))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background((Color(.systemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDisabled ? Color.gray50 : Color.gray30, lineWidth: 1)
            )
        }
        .disabled(isDisabled)
        .padding(.horizontal)
    }
}

struct StorachaSettingView: View {
    @ObservedObject var appState: StorachaAppState
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var manageAccountsAction: ((String) -> Void)?
    
    init(
        appState: StorachaAppState,
        disableBackAction: ((Bool) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        manageAccountsAction: ((String) -> Void)? = nil
    ) {
        self.appState = appState
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        self.manageAccountsAction = manageAccountsAction
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                StyledButton(
                    title: "Manage accounts",
                    subtitle: "Create or edit accounts",
                    isDisabled: appState.isBusy
                ) {
                    manageAccountsAction?("manage")
                }
                
                StyledButton(
                    title: "My spaces",
                    subtitle: "Access your saved spaces",
                    isDisabled: appState.isBusy
                ) {
                    manageAccountsAction?("spaces")
                }
                
                StyledButton(
                    title: "Join space",
                    subtitle: "Connect to an existing space",
                    isDisabled: appState.isBusy
                ) {
                    manageAccountsAction?("join")
                }
                
                Spacer()
            }
            .padding(.top, 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .edgesIgnoringSafeArea(.all)
        
            if appState.isBusy {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ActivityIndicator(style: .large, animate: .constant(true))
                        .foregroundColor(.white)
                    
                    Text("Checking session...")
                        .font(.montserrat(.medium, for: .callout))
                        .foregroundColor(.primary)
                }
                .padding(30)
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
            }
        }
        .onAppear {
            disableBackAction?(appState.isBusy)
        }
        .onReceive(Just(appState.isBusy)) { isBusy in
            disableBackAction?(isBusy)
        }
    }
}

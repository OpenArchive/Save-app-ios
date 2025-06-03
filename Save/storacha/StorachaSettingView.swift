//
//  StyledButton.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI

struct StyledButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(Color(.label))
                    Text(subtitle)
                        .font(.montserrat(.medium, for: .subheadline))
                        .foregroundColor(.gray70)
                }
                Spacer()
                Image(uiImage: (UIImage(named: "forward_arrow")?.withRenderingMode(.alwaysTemplate))!)
                    .foregroundColor(Color(.label))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background((Color(.systemBackground)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray30, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

struct StorachaSettingView: View {
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
    var manageAccountsAction: ((String) -> Void)?
    init(disableBackAction: ((Bool) -> Void)? = nil,dismissAction: (() -> Void)? = nil,manageAccountsAction: ((String) -> Void)? = nil) {
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
        self.manageAccountsAction = manageAccountsAction
    }
    var body: some View {
        VStack(spacing: 20) {
            StyledButton(title: "Manage accounts", subtitle: "Create or edit accounts") {
                manageAccountsAction?("manage")
            }
            StyledButton(title: "My spaces", subtitle: "Access your saved spaces") {
                manageAccountsAction?("spaces")
            }
            StyledButton(title: "Join space", subtitle: "Connect to an existing space") {
                manageAccountsAction?("join")
            }
            Spacer()
        } .padding(.top, 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .edgesIgnoringSafeArea(.all)
    }
}

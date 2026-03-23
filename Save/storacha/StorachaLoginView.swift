//
//  StorachaLoginView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.

import SwiftUI
import Combine

struct StorachaLoginView: View {
    @ObservedObject var state: AuthState
    var onLogin: () -> Void
    var onCreateAccount: () -> Void
    var onCancel: () -> Void
    var disableBackAction: ((Bool) -> Void)?
    var dismissAction: (() -> Void)?

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showIncorrectEmailMessage = false

    init(
        state: AuthState,
        onLogin: @escaping () -> Void,
        onCreateAccount: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        disableBackAction: ((Bool) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.onLogin = onLogin
        self.onCreateAccount = onCreateAccount
        self.onCancel = onCancel
        self.disableBackAction = disableBackAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        ZStack {
            GeometryReader { reader in
                VStack {
                    // Header
                    headerView
                        .padding(.top, 50)
                        .padding(.horizontal, 20)
                        .padding(.trailing, 20)
                    
                    // Account Label
                    Text(NSLocalizedString("Account", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.gray70)
                        .padding(.top, 50)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                    
                    // Email Field
                    CustomTextField(
                        placeholder: NSLocalizedString("Email", comment: ""),
                        text: $state.email,
                        hasError: showIncorrectEmailMessage || state.isLoginError,
                        onEditingChanged: { began in
                            if began {
                                showIncorrectEmailMessage = false
                                state.isLoginError = false
                            }
                        },
                        onCommit: {
                            if !isValidEmail(state.email) && !state.email.isEmpty {
                                showIncorrectEmailMessage = true
                            }
                        }
                    )
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Error Messages
                    errorMessagesView
                        .padding(.top, hasError ? 4 : 0)
                    
                    // Sign Up Link
                    signUpLinkView
                        .padding(.top, 40)
                    
                    Spacer()
                    
                    // Login Button
                    loginButton
                        .padding(.bottom, 40)
                        .padding(.horizontal, 20)
                }
                .frame(minHeight: reader.size.height)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .background(Color(.systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            // Loading Overlay
            if state.isBusy {
                loadingOverlay
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(NSLocalizedString("Error", comment: "")),
                message: Text(alertMessage),
                dismissButton: .default(Text(NSLocalizedString("OK", comment: "")))
            )
        }
        .onReceive(state.$error) { error in
            if let error = error {
                alertMessage = error.localizedDescription
                showingAlert = true
                state.error = nil
            }
        }
        .onAppear {
            disableBackAction?(state.isBusy)
        }
        .onReceive(Just(state.isBusy)) { isBusy in
            disableBackAction?(isBusy)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Circle()
                .fill(.gray10)
                .frame(width: 53, height: 53)
                .overlay(
                    Image("filecoin_logo_circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                )
                .padding(.trailing, 6)
            
            Text(NSLocalizedString("Log in using your registered email address.", comment: ""))
                .font(.montserrat(.medium, for: .subheadline))
        }
    }
    
    private var errorMessagesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.isLoginError {
                Text(NSLocalizedString("Invalid email or login failed.", comment: ""))
                    .foregroundColor(.red)
                    .font(.montserrat(.medium, for: .caption2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if showIncorrectEmailMessage {
                Text(NSLocalizedString("Invalid email", comment: ""))
                    .foregroundColor(.red)
                    .font(.montserrat(.medium, for: .caption2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var signUpLinkView: some View {
        HStack(alignment: .center) {
            Text(NSLocalizedString("Don't have an account?", comment: ""))
                .foregroundColor(.gray70)
                .font(.montserrat(.semibold, for: .callout))
            
            Button(action: onCreateAccount) {
                Text("[\(NSLocalizedString("Create one", comment: ""))](https://console.storacha.network/)")
            }
            .foregroundColor(.accent)
            .font(.montserrat(.semibold, for: .callout))
            .disabled(state.isBusy)
        }
    }
    
    private var loginButton: some View {
        Button(action: {
            if !state.isBusy && isValidFormState {
                onLogin()
            }
        }) {
            Text(NSLocalizedString("Login", comment: ""))
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: UIScreen.main.bounds.width / 2)
        .disabled(!isValidFormState || state.isBusy)
        .padding()
        .background(!isValidFormState || state.isBusy ? .gray50 : Color.accent)
        .foregroundColor(.black)
        .cornerRadius(10)
        .font(.montserrat(.semibold, for: .headline))
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(NSLocalizedString("Logging in...", comment: ""))
                        .font(.montserrat(.medium, for: .callout))
                        .foregroundColor(.white)
                }
                .padding(24)
            )
    }
    
    // MARK: - Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private var isValidFormState: Bool {
        let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedEmail.isEmpty && isValidEmail(trimmedEmail)
    }
    
    private var hasError: Bool {
        showIncorrectEmailMessage || state.isLoginError
    }
}

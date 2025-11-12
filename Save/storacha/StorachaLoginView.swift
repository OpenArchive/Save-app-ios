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
    var dispatch: (StorachaLoginAction) -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAlert = false
    @State private var alertMessage = ""

    enum Field {
        case email
    }
    
    var dismissAction: (() -> Void)?
    var disableBackAction: ((Bool) -> Void)?
   
    init(
        state: AuthState,
        dispatch: @escaping (StorachaLoginAction) -> Void,
        disableBackAction: ((Bool) -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.dispatch = dispatch
        self.dismissAction = dismissAction
        self.disableBackAction = disableBackAction
    }
    
    // Email validation function
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    // Check if email format is invalid
    private var isEmailFormatInvalid: Bool {
        !state.email.isEmpty && !isValidEmail(state.email)
    }
    
    var body: some View {
        ZStack {
            GeometryReader { reader in
                VStack {
                
                    HStack {
                        Circle().fill(.gray10)
                            .frame(width: 53, height: 53)
                            .overlay(
                                Image("storachaBird")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                            ).padding(.trailing, 6)
                        VStack(alignment: .leading) {
                            Text(NSLocalizedString("Log in using your registered email address", comment: ""))
                                .font(.montserrat(.medium, for: .subheadline))
                        }
                    }
                    .padding(.top,50).padding(.leading,20).padding(.trailing,40)
                    
                    Text(NSLocalizedString("Email", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.gray70)
                        .padding(.top,50)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading,20)
                    
                    CustomTextField(
                        placeholder: NSLocalizedString("Email Address", comment: ""),
                        text: $state.email,
                        onEditingChanged: { _ in
                            if state.isLoginError {
                                state.isLoginError = false
                            }
                        }
                    )
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        
                        if state.isLoginError {
                            Text(NSLocalizedString("Incorrect email or login failed.",comment: ""))
                                .foregroundColor(.red)
                                .font(.montserrat(.medium, for: .caption2))
                                .padding(.leading, 20)
                                .padding(.trailing, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, state.isLoginError ? 4 : 0)
                    
                    HStack(alignment: .center) {
                        Text(NSLocalizedString("No Account?",comment: ""))
                            .foregroundColor(.gray70)
                            .font(.montserrat(.semibold, for: .callout))
                        Button(action: { dispatch(.createAccount) }) {
                            Text("[\(NSLocalizedString("Create one", comment: "Learn more link"))](https://console.storacha.network/)")
                                .underline()
                        }
                        .foregroundColor(.accent)
                        .font(.montserrat(.semibold, for: .callout))
                        .disabled(state.isBusy)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                      
                        Button(action: {
                            if !state.isBusy && isValidFormState {
                                dispatch(.login)
                            }
                        }) {
                            Text(NSLocalizedString("Login",comment: ""))
                        }
                        .disabled(!isValidFormState || state.isBusy)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(!isValidFormState || state.isBusy ? .gray50 : Color.accent)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .font(.montserrat(.semibold, for: .headline))
                    }
                    .padding(.bottom, 40)
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                }
                .frame(minHeight: reader.size.height)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .background(Color(.systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
      
            if state.isBusy {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ActivityIndicator(style: .large, animate: .constant(true))
                                .foregroundColor(.white)
                            Text(NSLocalizedString("Logging in...",comment: ""))
                                .font(.montserrat(.medium, for: .callout))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color.clear)
                    )
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
                state.error = nil   // clear error inside AuthState
            }
        }
        .onAppear {
            disableBackAction?(state.isBusy)
        }
        .onReceive(Just(state.isBusy)) { isBusy in
            disableBackAction?(isBusy)
        }
    }
    
    private var isValidFormState: Bool {
        return !state.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isValidEmail(state.email) &&
               !isEmailFormatInvalid
    }
}

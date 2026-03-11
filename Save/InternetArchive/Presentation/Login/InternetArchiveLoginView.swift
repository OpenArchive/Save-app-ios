//
//  InternetArchiveView.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI
import FactoryKit

struct InternetArchiveLoginView: View {

    @ObservedObject var viewModel: InternetArchiveLoginViewModel

    var body: some View {
        if #available(iOS 15.0, *) {
            InternetArchiveLoginContent(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
enum Field: Hashable {
    case username
    case password
}

struct InternetArchiveLoginContent: View {

    @ObservedObject var viewModel: InternetArchiveLoginViewModel
    @State private var keyboardOffset: CGFloat = 0
    @State private var isShowPassword = false
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var focusedField: Field?
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        accountHeader
                        emailField
                        passwordField
                        errorMessage
                        createAccountRow
                        Spacer(minLength: 20)
                        buttonsRow
                    }
                    .frame(minHeight: reader.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
                }

                if viewModel.isBusy {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        )
                }
            }
        }
        .onChange(of: viewModel.userName) { _ in
            if viewModel.isLoginError { viewModel.clearError() }
        }
        .onChange(of: viewModel.password) { _ in
            if viewModel.isLoginError { viewModel.clearError() }
        }
    }
    
    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().fill(.gray10)
                .frame(width: 48, height: 48)
                .overlay(
                    Image("internet_archive_teal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                )
            Text(NSLocalizedString("Upload your media to a free public account on the Internet Archive.", comment: ""))
                .font(.montserrat(.medium, for: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 46)
        .padding(.horizontal, 20)
    }

    private var accountHeader: some View {
        Text(NSLocalizedString("Account", comment: ""))
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
            .padding(.top, 35)
            .padding(.leading, 20)
    }

    private var emailField: some View {
        ZStack(alignment: .leading) {
            if viewModel.userName.isEmpty {
                Text(NSLocalizedString("Email", comment: ""))
                    .italic()
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(.textEmpty)
                    .padding(.leading, 5)
            }
            TextField("", text: $viewModel.userName)
                .autocapitalization(.none)
                .font(.montserrat(.medium, for: .footnote))
                .foregroundColor(.gray70)
                .submitLabel(.next)
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .username)
                .onSubmit { focusedField = .password }
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor(forField: .username), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }

    private var passwordField: some View {
        ZStack(alignment: .leading) {
            HStack {
                ZStack(alignment: .leading) {
                    if viewModel.password.isEmpty {
                        Text(NSLocalizedString("Password", comment: ""))
                            .italic()
                            .font(.montserrat(.medium, for: .footnote))
                            .foregroundColor(.textEmpty)
                            .padding(.leading, 5)
                    }
                    if isShowPassword {
                        TextField("", text: $viewModel.password)
                            .font(.montserrat(.medium, for: .footnote))
                            .focused($focusedField, equals: .password)
                            .foregroundColor(.gray70)
                    } else {
                        SecureField("", text: $viewModel.password)
                            .font(.montserrat(.medium, for: .footnote))
                            .focused($focusedField, equals: .password)
                            .foregroundColor(.gray70)
                    }
                }
                Button { isShowPassword.toggle() } label: {
                    Image(isShowPassword ? "eye_open" : "eye_close")
                        .foregroundColor(.gray70)
                }
            }
        }
        .padding()
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor(forField: .password), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if viewModel.isLoginError {
            Text(NSLocalizedString("Incorrect email or password", comment: ""))
                .foregroundColor(.red)
                .font(.montserrat(.medium, for: .caption2))
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var createAccountRow: some View {
        HStack {
            Text(NSLocalizedString("No Account?", comment: ""))
                .foregroundColor(.gray70)
                .font(.montserrat(.semibold, for: .callout))
            Button(action: { viewModel.createAccount() }) {
                Text(NSLocalizedString("Create one", comment: ""))
            }
            .foregroundColor(.accent)
            .font(.montserrat(.semibold, for: .callout))
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private var buttonsRow: some View {
        HStack(spacing: 10) {
            Button(action: { viewModel.cancel() }) {
                Text(NSLocalizedString("Back", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .foregroundColor(viewModel.isBusy ? .gray50 : (colorScheme == .dark ? .white : .black))
            .font(.montserrat(.semibold, for: .headline))
            .disabled(viewModel.isBusy)

            Button(action: { viewModel.login() }) {
                Text(NSLocalizedString("Next", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.isValid)
            .padding()
            .background(!viewModel.isValid ? .gray50 : Color.accent)
            .foregroundColor(.black)
            .cornerRadius(10)
            .font(.montserrat(.semibold, for: .headline))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func borderColor(forField field: Field) -> Color {
        if viewModel.isLoginError {
            return .red
        } else if focusedField == field {
            return .accent // teal
        } else {
            return .gray70
        }
    }
}

struct InternetArchiveLoginView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            InternetArchiveLoginContent(viewModel: InternetArchiveLoginViewModel(useCase: Container.shared.internetArchiveLoginUseCase()))
        } else {
            EmptyView()
        }
    }
}

struct WorkingOverlayRepresentable: UIViewRepresentable {
    @Binding var isShowing: Bool
    
    func makeUIView(context: Context) -> WorkingOverlay {
        let overlay = WorkingOverlay()
        return overlay
    }
    
    func updateUIView(_ uiView: WorkingOverlay, context: Context) {
        uiView.isHidden = !isShowing
    }
}

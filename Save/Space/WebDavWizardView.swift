//
//  WebDavWizardView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct WebDavWizardView: View {
    @ObservedObject var viewModel: WebDavWizardViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case url, username, password
    }

    // MARK: - Layout Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 20
        static let headerTopPadding: CGFloat = 46
        static let headerBottomPadding: CGFloat = 45
        static let sectionSpacing: CGFloat = 20
        static let accountTopPadding: CGFloat = 45
        static let buttonSpacing: CGFloat = 10
        static let buttonBottomPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 10
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    serverSection
                    accountSection
                    errorSection
                    Spacer(minLength: Layout.sectionSpacing)
                }
            }

            VStack {
                Spacer()
                buttonsSection
            }

            if viewModel.isBusy {
                loadingOverlay
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alertOverlay)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.gray10)
                .frame(width: 48, height: 48)
                .overlay(
                    Image("private_server_teal")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                )
            Text(NSLocalizedString("Connect to a WebDAV-compatible servers, e.g. Nexcloud and ownCloud.", comment: ""))
                .font(.montserrat(.medium, for: .subheadline))
                .foregroundColor(.gray70)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            sectionHeader(NSLocalizedString("Server info", comment: ""))

            CustomTextField(
                placeholder: NSLocalizedString("Enter URL", comment: ""),
                text: $viewModel.urlString,
                isError: viewModel.urlHasError,
                onCommit: {
                    viewModel.fixUrlOnCommit()
                    focusedField = .username
                }
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            sectionHeader(NSLocalizedString("Account", comment: ""))
                .padding(.top, Layout.accountTopPadding)

            CustomTextField(
                placeholder: NSLocalizedString("Username", comment: ""),
                text: $viewModel.username,
                isError: viewModel.usernameHasError,
                onCommit: { focusedField = .password }
            )

            PasswordFieldWithReveal(
                text: $viewModel.password,
                placeholder: NSLocalizedString("Password", comment: ""),
                focusedField: $focusedField,
                field: .password,
                isFocused: focusedField == .password,
                isError: viewModel.passwordHasError,
                onSubmit: {
                    focusedField = nil
                    viewModel.connect()
                }
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
    }

    @ViewBuilder
    private var errorSection: some View {
        if !viewModel.errorMessage.isEmpty {
            Text(viewModel.errorMessage)
                .font(.montserrat(.medium, for: .caption2))
                .foregroundColor(.redButton)
                .padding(.top, 8)
                .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    private var buttonsSection: some View {
        HStack(spacing: Layout.buttonSpacing) {
            Button { viewModel.cancel() } label: {
                Text(NSLocalizedString("Back", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .font(.montserrat(.semibold, for: .headline))
            .disabled(viewModel.isBusy)

            Button { viewModel.connect() } label: {
                Text(NSLocalizedString("Next", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.isValid || viewModel.isBusy)
            .padding()
            .background(viewModel.isValid ? Color.accent : Color.gray50)
            .foregroundColor(.black)
            .cornerRadius(Layout.cornerRadius)
            .font(.montserrat(.semibold, for: .headline))
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.buttonBottomPadding)
    }

    private var loadingOverlay: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .overlay(
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            )
    }

    @ViewBuilder
    private var alertOverlay: some View {
        if viewModel.showServerNotFoundAlert {
            errorAlert(
                message: NSLocalizedString("A server with the specified hostname could not be found.", comment: ""),
                dismiss: viewModel.dismissServerNotFoundAlert
            )
        }
        if viewModel.showDuplicateCredentialsAlert {
            errorAlert(
                message: NSLocalizedString("You already have a server with these credentials.", comment: ""),
                dismiss: viewModel.dismissDuplicateCredentialsAlert
            )
        }
    }

    private func errorAlert(message: String, dismiss: @escaping () -> Void) -> some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .overlay(
                CustomAlertView(
                    title: NSLocalizedString("Error", comment: ""),
                    message: message,
                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                    iconImage: Image("ic_error"),
                    iconTint: .gray,
                    primaryButtonAction: dismiss,
                    showCheckbox: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            .onTapGesture(perform: dismiss)
    }
}

// MARK: - PasswordFieldWithReveal

private struct PasswordFieldWithReveal: View {
    @Binding var text: String
    var placeholder: String
    var focusedField: FocusState<WebDavWizardView.Field?>.Binding
    var field: WebDavWizardView.Field
    var isFocused: Bool
    var isError: Bool
    var onSubmit: () -> Void

    @State private var isRevealed = false

    private var borderColor: Color {
        if isError { return .redButton }
        if isFocused { return .accent }
        return .gray70
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .italic()
                    .font(.montserrat(.medium, for: .footnote))
                    .foregroundColor(.textEmpty)
                    .padding(.leading, 16)
            }

            HStack {
                Group {
                    if isRevealed {
                        TextField("", text: $text, onCommit: onSubmit)
                    } else {
                        SecureField("", text: $text)
                            .onSubmit(onSubmit)
                    }
                }
                .font(.montserrat(.medium, for: .footnote))
                .foregroundColor(.gray70)
                .focused(focusedField, equals: field)

                Button { isRevealed.toggle() } label: {
                    Image(isRevealed ? "eye_open" : "eye_close")
                        .foregroundColor(.gray70)
                }
            }
            .padding(12)
        }
        .frame(height: 50)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .background(Color.textboxBg)
        .padding(.bottom, 8)
    }
}

//
//  TesterEmailDialogView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct TesterEmailDialogView: View {

    let onContinue: (String) -> Void
    let onSkip: () -> Void

    @State private var email: String = ""
    @State private var showInvalidEmail = false

    private var isValidEmail: Bool {
        let regex = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(.accent)
                .padding(.top, 5)
                .padding(.bottom, 10)

            Text("Staging Build — Tester ID")
                .font(.montserrat(.bold, for: .headline))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text("Enter your email to help us track issues during testing. It is stored locally and only sent to our analytics dashboard.")
                .font(.montserrat(.medium, for: .subheadline))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .foregroundColor(.alertSubtitle)
                .padding(.bottom, 10)
         
                CustomTextField(
                    placeholder: "Email",
                    text: $email,
                    hasError: showInvalidEmail, keyboardType: .emailAddress
                )

                if showInvalidEmail {
                    Text("Please enter a valid email address")
                        .font(.montserrat(.medium, for: .caption2))
                        .foregroundColor(.red)
                }

            HStack(spacing: 10) {
                CustomButton(
                    title: "Skip",
                    backgroundColor: .clear,
                    textColor: .primary,
                    isOutlined: false,
                    action: onSkip
                )
                CustomButton(
                    title: "Continue",
                    backgroundColor: .accent,
                    textColor: .primary,
                    action: {
                        if isValidEmail {
                            onContinue(email.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            showInvalidEmail = true
                        }
                    }
                )
            }
            .padding(.top, 15)
            .padding(.bottom, 10)
        }
        .padding(.all, 10)
        .background(Color.alertBg)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
}

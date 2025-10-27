//
//  VerificationSentView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct VerificationSentView: View {
    @ObservedObject var authState: AuthState
    var email: String
    var onVerified: () -> Void
    var onTimeout: () -> Void
    @State private var isPolling = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if #available(iOS 14.0, *) {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ActivityIndicator(style: .large, animate: .constant(true))
            }
            
            Image(systemName: "envelope.badge")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)
            
            Text(NSLocalizedString("Verification Email Sent", comment: ""))
                .font(.montserrat(.bold, for: .headline))
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("Please check your inbox and click the link on the verification email.", comment: ""))
                .font(.montserrat(.medium, for: .subheadline))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            if !email.isEmpty {
                Text(  String(format: NSLocalizedString(
                    "Sent to: %@",
                    comment: "placeholder is 'email'"), email))
                    .font(.montserrat(.medium, for: .caption))
                    .foregroundColor(.gray)
            }
            HStack(spacing: 4) {
                            Text(NSLocalizedString("Email is incorrect?", comment: ""))
                                .font(.montserrat(.bold, for: .subheadline))
                                .foregroundColor(.gray70)
                            
                            Button(action: {
                                authState.stopVerificationPolling()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text(NSLocalizedString("Change now.", comment: ""))
                                    .font(.montserrat(.bold, for: .subheadline))
                                    .underline()
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.top, 10)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            startVerificationPolling()
        }
        .onDisappear {
            authState.stopVerificationPolling()
        }
    }
    
    private func startVerificationPolling() {
        guard !isPolling else { return }
        isPolling = true
        
        authState.startVerificationPolling { isVerified in
            DispatchQueue.main.async {
                self.isPolling = false
                if isVerified {
                    onVerified()
                } else {
                    onTimeout()
                }
            }
        }
    }
}

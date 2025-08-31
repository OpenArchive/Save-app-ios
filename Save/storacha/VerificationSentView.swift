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
            
            Text("Verification Email Sent")
                .font(.montserrat(.bold, for: .headline))
                .multilineTextAlignment(.center)

            Text("Please check your inbox and click the link on the verification email.")
                .font(.montserrat(.medium, for: .subheadline))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            if !email.isEmpty {
                Text("Sent to: \(email)")
                    .font(.montserrat(.medium, for: .caption))
                    .foregroundColor(.gray)
            }

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

//
//  VerificationSentView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct VerificationSentView: View {
    var email: String
    var onVerified: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if #available(iOS 14.0, *) {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Fallback on earlier versions
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
            
            // Optionally display the email address
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
          
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onVerified()
            }
        }
    }
}

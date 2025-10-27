//
//  VerificationSuccessView.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import SwiftUI

struct VerificationSuccessView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(NSLocalizedString("Your email has been verified,\nand the spaces have been added to Save.", comment: ""))
                .font(.montserrat(.medium, for: .subheadline))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Image("hands-mobile")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 40)
                .padding(.top, 20)

            Spacer()
            
            Button(action: {
                onDismiss()
            }) {
                Text(LocalizedStringKey("Done"))
                    .font(.montserrat(.semibold, for: .headline))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
    }
}


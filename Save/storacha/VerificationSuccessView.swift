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
                .font(.montserrat(.bold, for: .headline))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
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
                Text(LocalizedStringKey("Done")).frame(maxWidth: .infinity)
                    .font(.montserrat(.semibold, for: .headline))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .frame(maxWidth: UIScreen.main.bounds.width / 2)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}


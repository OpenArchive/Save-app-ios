//
//  PublicDataWarningAlertView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct PublicDataWarningAlertView: View {
    var onContinue: () -> Void
    var onCancel: () -> Void

    @State private var checkboxChecked = false
    @State private var timeRemaining = 10
    @State private var timer: Timer?

    private let message = NSLocalizedString(
        "Do not upload private or sensitive information unless it is encrypted.\n\nUploads to the decentralized web/Filecoin- are accessible to anyone who has the file identifier (CID).\n\nDecentralized storage is designed for long-term durability. Removing a file will not remove all copies that exist across the network.",
        comment: "Public data warning - full message"
    )

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(Color.accentColor)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text(NSLocalizedString("Warning: Public Data", comment: "Public data warning title"))
                .font(.montserrat(.bold, for: .headline))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(message)
            .font(.montserrat(.medium, for: .subheadline))
            .foregroundColor(.alertSubtitle)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Toggle(isOn: $checkboxChecked) {
                Text(NSLocalizedString("I'm okay with this", comment: "Public data warning checkbox"))
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.alertSubtitle)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text(NSLocalizedString("Cancel", comment: ""))
                        .font(.montserrat(.semibold, for: .callout))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.primary)
                }

                Button(action: onContinue) {
                    Text(continueButtonTitle)
                        .font(.montserrat(.semibold, for: .callout))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(isContinueEnabled ? .primary : .gray)
                        .background(isContinueEnabled ? Color.accent : Color(UIColor.systemGray4))
                        .cornerRadius(8)
                }
                .disabled(!isContinueEnabled)
            }
            .padding(.bottom, 16)
        }
        .padding(.all, 16)
        .background(Color.alertBg)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal, 24)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var isContinueEnabled: Bool {
        checkboxChecked && timeRemaining <= 0
    }

    private var continueButtonTitle: String {
        if timeRemaining > 0 {
            return String(format: NSLocalizedString("Continue (%d)", comment: "Public data warning continue with countdown"), timeRemaining)
        } else {
            return NSLocalizedString("Continue", comment: "")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
        timer?.tolerance = 0.1
    }
}

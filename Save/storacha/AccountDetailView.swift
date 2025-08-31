//
//  AccountDetailView.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject var appState: StorachaAppState
    var email: String
    var onLogout: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: 80)

            Text(email)
                .font(.montserrat(.semibold, for: .subheadline))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)

            if appState.isLoading {
                if #available(iOS 14.0, *) {
                    ProgressView("Loading usage...")
                        .padding(.top, 20) .font(.montserrat(.medium, for: .caption))
                } else {
                    // Fallback on earlier versions
                }
            } else if let usage = appState.usage {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Total Usage: \(usage.totalUsage.human)")
                        .font(.montserrat(.semibold, for: .title))

                    ForEach(usage.spaces) { space in
                        HStack {
                            Text(space.name)
                                .font(.montserrat(.medium, for: .body))
                            Spacer()
                            Text(space.usage.human)
                                .font(.montserrat(.medium, for: .footnote))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal)
            } else if let error = appState.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("No usage data available")
                    .foregroundColor(.gray70)
                    .padding(.top, 20)
            }

            Spacer()

            Button(action: { onLogout() }) {
                Text("Log out")
                    .font(.montserrat(.semibold, for: .headline))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .onAppear {
            Task {
                if let sessionId = appState.currentUser?.sessionId {
                    await appState.loadUsage(sessionId: sessionId)
                }
            }
        }
    }
}

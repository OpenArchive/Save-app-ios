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
    
    @State private var activeSortType: SortType = .name
    @State private var nameSortAscending = true
    @State private var sizeSortAscending = false // Start with descending for size
    
    enum SortType {
        case name, size
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
               
                Text(email)
                    .font(.montserrat(.medium, for: .body))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 20)

                if appState.isLoading {
                    // Single progress indicator for both plan and spaces
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    // Plan Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(extractPlanName()) Plan")
                            .font(.montserrat(.bold, for: .headline))
                            .foregroundColor(.primary)
                        if let usage = appState.usage {
                            Text("\(usage.totalUsage.human) used")
                                .font(.montserrat(.medium, for: .body))
                                .foregroundColor(.gray70)
                        } else {
                            Text("0 MB used")
                                .font(.montserrat(.medium, for: .body))
                                .foregroundColor(.gray70)
                        }
                    }
                    .padding(.horizontal)

                    // Storage Spaces Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("Storage Spaces", comment: ""))
                            .font(.montserrat(.bold, for: .headline))
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        // Sort buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                if activeSortType == .name {
                                    // Toggle ascending/descending
                                    nameSortAscending.toggle()
                                } else {
                                    // Switch to name sort
                                    activeSortType = .name
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(NSLocalizedString("Sort by Name", comment: ""))
                                        .font(.montserrat(.medium, for: .caption))
                                    if activeSortType == .name {
                                        Image(systemName: nameSortAscending ? "arrow.up" : "arrow.down")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                }
                                .foregroundColor(activeSortType == .name ? .accentColor : .gray70)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(activeSortType == .name ? Color.accentColor : .gray30, lineWidth: 1)
                                )
                            }
                            
                            Button(action: {
                                if activeSortType == .size {
                                    // Toggle ascending/descending
                                    sizeSortAscending.toggle()
                                } else {
                                    // Switch to size sort
                                    activeSortType = .size
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(NSLocalizedString("Sort by Size", comment: ""))
                                        .font(.montserrat(.medium, for: .caption))
                                    if activeSortType == .size {
                                        Image(systemName: sizeSortAscending ? "arrow.up" : "arrow.down")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                }
                                .foregroundColor(activeSortType == .size ? .accentColor : .gray70)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(activeSortType == .size ? Color.accentColor : .gray30, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Spaces list
                        if let usage = appState.usage {
                            let sortedSpaces: [StorachaSpaceUsage] = {
                                if activeSortType == .name {
                                    return nameSortAscending
                                        ? usage.spaces.sorted(by: { $0.name < $1.name })
                                        : usage.spaces.sorted(by: { $0.name > $1.name })
                                } else {
                                    return sizeSortAscending
                                        ? usage.spaces.sorted(by: { $0.usage.bytes < $1.usage.bytes })
                                        : usage.spaces.sorted(by: { $0.usage.bytes > $1.usage.bytes })
                                }
                            }()
                            
                            VStack(spacing: 8) {
                                ForEach(sortedSpaces) { space in
                                    HStack {
                                        Text(space.name)
                                            .font(.montserrat(.medium, for: .body))
                                            .foregroundColor(.black)
                                        Spacer()
                                        Text(space.usage.human)
                                            .font(.montserrat(.medium, for: .body))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                        } else if appState.error != nil {
                            Text("Error loading spaces")
                                .foregroundColor(.red)
                                .font(.montserrat(.medium, for: .caption))
                                .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 40)

                // Logout button
                Button(action: { onLogout() }) {
                    Text(NSLocalizedString("Logout", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await refreshUsage()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            Task {
                if let sessionId = appState.currentUser?.sessionId {
                    await appState.loadUsage(sessionId: sessionId)
                }
            }
        }
    }
    
    private func refreshUsage() async {
        print("🔄 [refreshUsage] Starting refresh...")
        
        guard let sessionId = appState.currentUser?.sessionId else {
            print("❌ [refreshUsage] No session ID available")
            return
        }
        
        print("🔄 [refreshUsage] Session ID: \(sessionId)")
        
        // Use Task.detached to prevent cancellation from parent context
        await Task.detached(priority: .userInitiated) {
            await self.appState.loadUsage(sessionId: sessionId)
        }.value
        
        print("✅ [refreshUsage] Refresh completed")
    }
    
    private func extractPlanName() -> String {
        guard let usage = appState.usage else {
            return "Starter"
        }
    
        let components = usage.planProduct.split(separator: ":")
        if components.count >= 3 {
            let webComponent = String(components[2])
            let planName = webComponent.split(separator: ".").first ?? "Starter"
            return String(planName).capitalized
        }
        
        return "Starter"
    }
}

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
    @State private var sizeSortAscending = false
    @State private var showLogoutAlert = false
    
    enum SortType {
        case name, size
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    emailSection
                    
                    if appState.isLoading {
                        loadingView
                    } else {
                        planSection
                        storageSpacesSection
                    }
                    
                    Spacer(minLength: 40)
                    
                    logoutButton
                }
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await refreshUsage()
            }
            .background(Color(.systemBackground))
            .onAppear {
                loadUsageData()
            }
            
            if showLogoutAlert {
                logoutAlertOverlay
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emailSection: some View {
        Text(email)
            .font(.montserrat(.medium, for: .body))
            .foregroundColor(.gray)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.top, 20)
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
    
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(extractPlanName()) Plan")
                .font(.montserrat(.bold, for: .headline))
                .foregroundColor(.primary)
            
            Text(usageText)
                .font(.montserrat(.medium, for: .body))
                .foregroundColor(.gray70)
        }
        .padding(.horizontal)
    }
    
    private var usageText: String {
        if let usage = appState.usage {
            return "\(formatStorageSize(bytes: Int64(usage.totalUsage.bytes))) used"
        } else {
            return "0 MB used"
        }
    }
    
    private var storageSpacesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Storage Spaces", comment: ""))
                .font(.montserrat(.bold, for: .headline))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            sortButtons
            spacesList
        }
    }
    
    private var sortButtons: some View {
        HStack(spacing: 12) {
            sortButton(
                type: .name,
                title: NSLocalizedString("Sort by Name", comment: ""),
                isAscending: nameSortAscending
            )
            
            sortButton(
                type: .size,
                title: NSLocalizedString("Sort by Size", comment: ""),
                isAscending: sizeSortAscending
            )
        }
        .padding(.horizontal)
    }
    
    private func sortButton(type: SortType, title: String, isAscending: Bool) -> some View {
        Button(action: {
            handleSortTap(type: type)
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.montserrat(.medium, for: .caption))
                
                if activeSortType == type {
                    Image(systemName: isAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(activeSortType == type ? .accentColor : .gray70)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(activeSortType == type ? Color.accentColor : .gray30, lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var spacesList: some View {
        if let usage = appState.usage {
            VStack(spacing: 8) {
                ForEach(sortedSpaces(from: usage)) { space in
                    spaceRow(space: space)
                }
            }
        } else if appState.error != nil {
            errorView
        }
    }
    
    private func spaceRow(space: StorachaSpaceUsage) -> some View {
        HStack {
            Text(space.name)
                .font(.montserrat(.medium, for: .subheadline))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formatStorageSize(bytes: Int64(space.usage.bytes)))
                .font(.montserrat(.medium, for: .subheadline))
                .foregroundColor(.gray70)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var errorView: some View {
        Text("Error loading spaces")
            .foregroundColor(.red)
            .font(.montserrat(.medium, for: .caption))
            .padding(.horizontal)
    }
    
    private var logoutButton: some View {
        HStack {
            Spacer()
            Button(action: {
                showLogoutAlert = true
            }) {
                Text(NSLocalizedString("Logout", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: UIScreen.main.bounds.width / 2)
            .padding()
            .background(Color.accent)
            .foregroundColor(.black)
            .cornerRadius(10)
            .font(.montserrat(.semibold, for: .headline))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var logoutAlertOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            CustomAlertView(
                title: NSLocalizedString("Logout", comment: ""),
                message: NSLocalizedString("Are you sure you want to logout?", comment: ""),
                primaryButtonTitle: NSLocalizedString("Logout", comment: ""),
                iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                iconTint: .accent,
                primaryButtonAction: {
                    showLogoutAlert = false
                    onLogout()
                },
                secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                secondaryButtonAction: {
                    showLogoutAlert = false
                },
                showCheckbox: false
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
    private func loadUsageData() {
        Task {
            if let sessionId = appState.currentUser?.sessionId {
                await appState.loadUsage(sessionId: sessionId)
            }
        }
    }
    
    private func refreshUsage() async {
        guard let sessionId = appState.currentUser?.sessionId else { return }
        
        await Task.detached(priority: .userInitiated) {
            await self.appState.loadUsage(sessionId: sessionId)
        }.value
    }
    
    private func handleSortTap(type: SortType) {
        if activeSortType == type {
            // Toggle ascending/descending
            switch type {
            case .name:
                nameSortAscending.toggle()
            case .size:
                sizeSortAscending.toggle()
            }
        } else {
            // Switch to new sort type
            activeSortType = type
        }
    }
    
    private func sortedSpaces(from usage: StorachaAccountUsageResponse) -> [StorachaSpaceUsage] {
        switch activeSortType {
        case .name:
            return nameSortAscending
                ? usage.spaces.sorted(by: { $0.name < $1.name })
                : usage.spaces.sorted(by: { $0.name > $1.name })
        case .size:
            return sizeSortAscending
                ? usage.spaces.sorted(by: { $0.usage.bytes < $1.usage.bytes })
                : usage.spaces.sorted(by: { $0.usage.bytes > $1.usage.bytes })
        }
    }
    
    private func formatStorageSize(bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        let gb = mb / 1024
        let tb = gb / 1024
        
        if tb >= 1 {
            return String(format: "%.2f TB", tb)
        } else if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.2f MB", mb)
        }
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

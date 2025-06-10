//
//  LicenseToggles.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

// MARK: - LicenseToggles
struct LicenseToggles: View {
    @ObservedObject var store: ServerSettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(NSLocalizedString("Allow anyone to remix and share?", comment: "Remix Toggle"), isOn: Binding(
                get: { store.state.allowRemix },
                set: { newValue in
                    store.dispatch(action: .toggleAllowRemix(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
            
            Toggle(NSLocalizedString("Require them to share like you have?", comment: "ShareAlike Toggle"), isOn: Binding(
                get: { store.state.requireShareAlike },
                set: { newValue in
                    store.dispatch(action: .toggleRequireShareAlike(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent)
                .disabled(!store.state.allowRemix).font(.montserrat(.medium, for: .subheadline))
            
            Toggle(NSLocalizedString("Allow commercial use?", comment: "Commercial Use Toggle"), isOn: Binding(
                get: { store.state.allowCommercialUse },
                set: { newValue in
                    store.dispatch(action: .toggleAllowCommercialUse(newValue))
                    store.dispatch(action: .updateLicense)
                }
            )) .toggleTint(.accent).font(.montserrat(.medium, for: .subheadline))
            
            if let licenseURL = store.state.licenseURL {
                if #available(iOS 14.0, *) {
                    Link(NSLocalizedString(licenseURL, comment: "License Link"), destination: URL(string: licenseURL)!)
                        .foregroundColor(.accentColor)
                        .padding(.top, 10) .font(.montserrat(.medium, for: .subheadline))
                } else {
                    // Fallback on earlier versions
                }
            }
            
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    var title: String
    
    var body: some View {
        Text(NSLocalizedString(title, comment: "\(title) Section"))
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
            .padding(.top,20)
            .padding(.bottom,10)
    }
    
}

// MARK: - ToggleTintModifier
struct ToggleTintModifier: ViewModifier {
    var color: Color
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.tint(color)
        } else {
            content.accentColor(color)
        }
    }
}

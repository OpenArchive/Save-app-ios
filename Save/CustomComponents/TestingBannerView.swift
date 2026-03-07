//
//  TestingBannerView.swift
//  Save
//
//  Created by navoda on 2026-03-07.
//  Copyright © 2026 Open Archive. All rights reserved.
//


import SwiftUI

/// Transparent red banner shown at bottom of screens when enhanced analytics is enabled.
struct TestingBannerView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Text("TESTING ONLY — NOT FOR PUBLIC USE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Color(red: 0.55, green: 0, blue: 0).opacity(0.8)
        )
    }
}
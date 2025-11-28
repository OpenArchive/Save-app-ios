//
//  QRCodeView.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct QRCodeView: View {
    @EnvironmentObject var spaceState: SpaceState
    var onComplete: (() -> Void)?
    
    @State private var isLoading = false
    @State private var didString: String?
    @State private var showToast = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let did = didString {
                contentView(did: did)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(toastOverlay)
        .onAppear {
            loadDID()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text(NSLocalizedString("Loading QR code...", comment: ""))
                .font(.montserrat(.semibold, for: .headline))
                .foregroundColor(.gray70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func contentView(did: String) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                qrCodeCard(did: did)
                Spacer().frame(height: 40)
                mySpacesButton
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.gray10)
                .frame(width: 53, height: 53)
                .overlay(
                    Image("storachaBird")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                )
                .padding(.trailing, 6)
            
            Text(NSLocalizedString("Here is your identity.\nShare this QR code or ID with an admin so they can add you to their space.", comment: ""))
                .font(.montserrat(.medium, for: .callout))
                .foregroundColor(.gray70)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
    }
    
    private func qrCodeCard(did: String) -> some View {
        VStack(spacing: 20) {
            qrCodeImage(did: did)
            didStringSection(did: did)
            infoText
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 24)
    }
    
    private func qrCodeImage(did: String) -> some View {
        Group {
            if let qrImage = Utils.generateQRCode(from: did) {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 280, height: 280)
            } else {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 30)
    }
    
    private func didStringSection(did: String) -> some View {
        HStack(spacing: 0) {
            Text(did)
                .font(.montserrat(.medium, for: .footnote))
                .foregroundColor(.backButton)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 40)
            
            Button(action: copyDID) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
                    .frame(width: 60)
            }
        }
        .background(didBackgroundColor)
        .cornerRadius(8)
        .padding(.horizontal, 20)
    }
    
    private var didBackgroundColor: Color {
        colorScheme == .dark
            ? Color(white: 0.2)
            : Color(red: 1.0, green: 0.984, blue: 0.941)
    }
    
    private var infoText: some View {
        Text(NSLocalizedString("Once the admin approves you,\nthe space will appear under My Spaces.", comment: ""))
            .font(.montserrat(.medium, for: .caption))
            .foregroundColor(.black)
            .lineLimit(4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .padding(.bottom, 30)
    }
    
    private var mySpacesButton: some View {
        HStack {
            Spacer()
            Button(action: {
                onComplete?()
            }) {
                Text(NSLocalizedString("My Spaces", comment: ""))
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
    
    private var toastOverlay: some View {
        VStack {
            Spacer()
            if showToast {
                Text(NSLocalizedString("DID copied to clipboard", comment: ""))
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showToast)
            }
            Spacer().frame(height: 100)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadDID() {
        isLoading = true
        Task {
            do {
                let did = try spaceState.getOrCreateDID()
                self.didString = did
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.isLoading = false
            } catch {
                print("Failed to load/generate DID: \(error)")
                self.isLoading = false
            }
        }
    }
    
    private func copyDID() {
        UIPasteboard.general.string = didString
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

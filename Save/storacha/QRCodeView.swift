//
//  QRCodeVie.swift
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
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 20) {
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text(NSLocalizedString("Loading QR code...", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.gray70)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let did = didString {
                Spacer().frame(height: 20)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image("storachaBird")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                        
                        Text(NSLocalizedString("This is your QR code to request access, Please ask the admin to scan your code to gain access to space.", comment: ""))
                            .font(.montserrat(.medium, for: .callout))
                            .foregroundColor(.gray70)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                
                Spacer().frame(height: 40)
                
                VStack(spacing: 20) {
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
                    
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("DID ACCESS KEY", comment: ""))
                            .font(.montserrat(.bold, for: .caption))
                            .foregroundColor(.black)
                            .tracking(1)
                        
                        HStack(alignment: .top) {
                            Text(didString ?? "")
                                .font(.montserrat(.medium, for: .footnote))
                                .foregroundColor(.gray)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 20)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer(minLength: 8)
                            
                            Button(action: {
                                UIPasteboard.general.string = didString
                                showToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showToast = false
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.accent)
                                    .font(.system(size: 20))
                            }
                            .padding(.trailing, 20)
                        }
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: {
                    onComplete?()
                }) {
                    Text(NSLocalizedString("View Spaces", comment: ""))
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accent)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(
            
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
        )
        .onAppear {
            isLoading = true
            Task {
                do {
                    let did = try spaceState.getOrCreateDID()
                    self.didString = did
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.isLoading = false
                    }
                } catch {
                    print("Failed to load/generate DID: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}

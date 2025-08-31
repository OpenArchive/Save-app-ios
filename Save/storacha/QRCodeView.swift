//
//  QRCodeView 2.swift
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

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                if #available(iOS 14.0, *) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else {
                    
                }
                Text("Loading QR code...")
                    .font(.montserrat(.semibold, for: .headline))
                    .foregroundColor(.gray70)
            } else if let did = didString {
                Image("storachaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 80)
                    .padding(.top, 20)

                if let qrImage = Utils.generateQRCode(from: did) {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 240, height: 240)
                } else {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.red)
                }

                Text(didString ?? "").padding(.horizontal,20).font(.montserrat(.medium, for: .caption))
                    .foregroundColor(.gray70)
                Text("This is your QR code to request access. Please ask the admin to scan your code to gain access to a space.")
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.gray70)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()
            }
        }
        .onAppear {
            Task {
                do {
                    let did = try spaceState.getOrCreateDID()
                    self.didString = did
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isLoading = false
                    }
                } catch {
                    print("Failed to load/generate DID: \(error)")
                }
            }
        }
    }
}

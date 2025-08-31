//
//  ScanDIDView.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct ScanDIDView: View {
    @EnvironmentObject var didState: DIDState
    let spaceDid: String
    @Environment(\.presentationMode) var presentationMode
    @State private var typedDID: String = ""
    @State private var showScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Enter DID", text: $typedDID, onCommit: {
                    Task {
                        await addAndDismiss(did: typedDID)
                    }
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    withAnimation {
                        showScanner.toggle()
                    }
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.accentColor)
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)

            if showScanner {
                BarcodeScannerView { scannedValue in
                    Task {
                        await addAndDismiss(did: scannedValue)
                    }
                    showScanner = false
                }
                .frame(height: 300)
                .transition(.move(edge: .top))
                .padding(.trailing,16)
            }

            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: - Helper
    private func addAndDismiss(did: String) async {
        let trimmed = did.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await didState.addDID(for: spaceDid, did: trimmed)
        await didState.loadDIDs(for: spaceDid)
        presentationMode.wrappedValue.dismiss()
    }
}

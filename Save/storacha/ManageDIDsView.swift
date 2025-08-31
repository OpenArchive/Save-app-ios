//
//  ManageDIDsViewController.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct ManageDIDsView: View {
    @ObservedObject var didState: DIDState
    let spaceDid: String
    let disableBackAction: (Bool) -> Void
    
    @State private var didToDelete: String? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        if #available(iOS 15.0, *) {
            VStack(spacing: 12) {
                if didState.isLoading {
                    ProgressView("Loading DIDs...")
                        .font(.montserrat(.medium, for: .caption))
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if didState.dids.isEmpty {
                                Text("No DIDs available")
                                    .foregroundColor(.gray)
                                    .font(.montserrat(.medium, for: .body))
                                    .padding(.top, 40)
                            } else {
                                ForEach(didState.dids, id: \.self) { did in
                                    HStack {
                                        Image(systemName: "person.circle")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.accentColor)
                                            .padding(.trailing, 8)
                                        Text(did)
                                            .font(.montserrat(.medium, for: .body))
                                            .foregroundColor(Color(.label))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .truncationMode(.tail)
                                        Spacer()
                                        Button(action: {
                                            didToDelete = did
                                            showDeleteConfirmation = true
                                            disableBackAction(true)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.gray30, lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .compatTask {
                await didState.loadDIDs(for: spaceDid)
            }
            .overlay {
                if showDeleteConfirmation {
                    ZStack {
                        Color.black.opacity(0.2)
                            .compatIgnoresSafeArea()
                        
                        CustomAlertView(
                            title: NSLocalizedString("Revoke Access?", comment: ""),
                            message: String(format: NSLocalizedString(
                                "This will revoke access for this DID from the %@ app.",
                                comment: "Placeholder is app name"
                            ), Bundle.main.displayName),
                            primaryButtonTitle: NSLocalizedString("Revoke", comment: ""),
                            iconImage: Image("trash_icon"),
                            iconTint: .gray,
                            primaryButtonAction: {
                                showDeleteConfirmation = false
                                Task {
                                    await didState.revokeDID(for: spaceDid, did: didToDelete ?? "")
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    disableBackAction(false)
                                }
                            },
                            secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                            secondaryButtonAction: {
                                disableBackAction(false)
                                showDeleteConfirmation = false
                            },
                            showCheckbox: false,
                            isRemoveAlert: true
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
}


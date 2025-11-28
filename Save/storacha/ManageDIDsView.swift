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
            VStack(spacing: 12) {
                if didState.isLoading {
                    ProgressView(NSLocalizedString("Loading DIDs...", comment: ""))
                        .font(.montserrat(.medium, for: .caption))
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 40)
                } else {
                  
                   
                        if didState.dids.isEmpty {
                            VStack(spacing: 12) {
                            Spacer()
                            Text(NSLocalizedString("No DIDs currently have access to this space.\nTap 'Add' to grant access.", comment: ""))
                                .foregroundColor(.gray)
                                .font(.montserrat(.medium, for: .body))
                                .multilineTextAlignment(.center)
                                .padding(.top, 40)
                            Spacer()}}
                            else {
                                ScrollView {
                                    VStack(spacing: 12) {
                                ForEach(didState.dids, id: \.self) { did in
                                    HStack {
                                       
                                        Text(did)
                                            .font(.montserrat(.medium, for: .subheadline))
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
                                }  }
                                .padding(.top, 20)
                            }
                            .refreshable {
                                await didState.loadDIDs(for: spaceDid)
                            }
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
                            message: NSLocalizedString(
                                "This will revoke access to this DID for this space.",
                                comment: "Placeholder is app name"
                            ),
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
    }
}

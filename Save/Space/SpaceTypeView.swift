//
//  SpaceTypeView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct SpaceTypeView: View {

    let showInternetArchive: Bool
    var onWebDav: () -> Void
    var onInternetArchive: () -> Void
    var onStoracha: () -> Void

    @State private var showPublicDataWarning = false

    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString(
                "To get started, connect to a server to store your media.",
                comment: ""))
                .font(.montserrat(.semibold, for: .headline))
                .multilineTextAlignment(.center)
                .padding(.top, 52)

            Text(NSLocalizedString(
                "You can add multiple private servers and one IA Account at any time.",
                comment: ""))
                .font(.montserrat(.regular, for: .subheadline))
                .foregroundColor(Color(UIColor.subtitleText))
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            BigButtonView(
                icon: "private_server_teal",
                title: WebDavSpace.defaultPrettyName,
                subtitle: NSLocalizedString("Connect to a secure\nWebDAV server", comment: ""),
                action: onWebDav
            )
            .accessibilityIdentifier("viewPrivateServer")
            .padding(.bottom, 16)

            if showInternetArchive {
                BigButtonView(
                    icon: "internet_archive_teal",
                    title: IaSpace.defaultPrettyName,
                    subtitle: NSLocalizedString("Connect to a free \npublic server", comment: ""),
                    action: onInternetArchive
                ).accessibilityIdentifier("viewPrivateServer")
                .padding(.bottom, 16)
            }

            BigButtonView(
                icon: "filecoin_logo_teal",
                title: "Filecoin",
                subtitle: NSLocalizedString("Connect to a public \nDWeb server", comment: ""),
                action: {
                    if Settings.publicDataWarningShown {
                        onStoracha()
                    } else {
                        showPublicDataWarning = true
                    }
                }
            )
            .accessibilityIdentifier("viewStoracha")

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .trackScreen("SpaceType")
        .overlay {
            if showPublicDataWarning {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        PublicDataWarningAlertView(
                            onContinue: {
                                Settings.publicDataWarningShown = true
                                showPublicDataWarning = false
                                onStoracha()
                            },
                            onCancel: {
                                showPublicDataWarning = false
                            }
                        )
                    }
            }
        }
    }
}

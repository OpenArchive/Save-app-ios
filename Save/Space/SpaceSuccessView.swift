//
//  SpaceSuccessView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct SpaceSuccessView: View {

    let spaceName: String
    var onDone: () -> Void

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let imageHeight = geo.size.width - 70
                let imageMidY = geo.size.height / 2

                // Image centered on screen
                Image("hands-mobile")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 35)
                    .position(x: geo.size.width / 2, y: imageMidY)

                Text(String(
                    format: NSLocalizedString(
                        "You have successfully connected to %@!",
                        comment: "Placeholder is a server type or name"),
                    spaceName))
                    .font(.montserrat(.semibold, for: .headline))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width / 2, y: imageMidY - (imageHeight / 2) - 80)
            }

            // Done button pinned to bottom
            VStack {
                Spacer()
                Button(action: onDone) {
                    Text(NSLocalizedString("Done", comment: ""))
                        .font(.montserrat(.semibold, for: .callout))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.accent))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .navigationBarBackButtonHidden(true)
        .trackScreen("SpaceSetupSuccess")
    }
}

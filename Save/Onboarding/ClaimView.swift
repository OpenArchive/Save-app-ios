//
//  ClaimView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ClaimView: View {

    var onNext: () -> Void

    @State private var arrowOffset: CGFloat = 0

    private let words: [String] = String(
        format: NSLocalizedString("Share%1$@Archive%1$@Verify%1$@Encrypt",
                                  comment: "Placeholders will be replaced by newline"),
        "\n")
        .components(separatedBy: "\n")

    private let shakeTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    @State private var shakeIndex = 0
    private let shakeValues: [CGFloat] = [-10, 10, -8, 8, -5, 5, 0, 0, 0, 0]

    var body: some View {
        GeometryReader { geometry in
            let safeHeight = geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom
            let topHeight = safeHeight * 0.17
            let bottomHeight = geometry.size.height * 0.2

            VStack(spacing: 0) {
                logoSection(height: topHeight)

                claimSection

                Spacer(minLength: 0)

                bottomSection(height: bottomHeight)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .bottom) {
            if EnhancedAnalyticsConfig.isEnabled {
                TestingBannerView()
            }
        }
        .onTapGesture {
            onNext()
        }
        .onReceive(shakeTimer) { _ in
            withAnimation(.linear(duration: 0.3)) {
                shakeIndex = (shakeIndex + 1) % shakeValues.count
            }
        }
    }

    private func logoSection(height: CGFloat) -> some View {
        HStack {
            Image("save-open-archive-logo")
                .resizable()
                .aspectRatio(145.0 / 120.0, contentMode: .fit)
                .frame(width: 70)
                .padding(.leading, 16)
                .padding(.top, 16)
            Spacer()
        }
        .frame(height: height, alignment: .topLeading)
    }

    private var claimSection: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(words, id: \.self) { word in
                    accentedWord(word)
                }
            }

            Text(NSLocalizedString("Secure Mobile Media Preservation", comment: ""))
                .font(.montserrat(.bold, for: .body))
                .minimumScaleFactor(0.5)
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accentedWord(_ word: String) -> some View {
        let firstLetter = String(word.prefix(1))
        let rest = String(word.dropFirst())

        return (
            Text(firstLetter)
                .foregroundColor(Color(UIColor.accent))
            + Text(rest)
                .foregroundColor(Color(UIColor.label))
        )
        .font(.custom("Montserrat-Black", fixedSize: 59))
        .minimumScaleFactor(0.3)
        .lineLimit(1)
    }

    private func bottomSection(height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image("onboarding_app_hand")
                .resizable()
                .aspectRatio(518.0 / 627.0, contentMode: .fit)
                .frame(height: height)
                .offset(x: -8)

            HStack(spacing: 8) {
                Text(NSLocalizedString("Get Started", comment: ""))
                    .font(.montserrat(.bold, for: .body))
                    .accessibilityIdentifier("btGetStarted")

                Image("forward_arrow")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .offset(x: shakeValues[shakeIndex])
            }
            .padding(.leading, 28)

            Spacer()
        }
        .frame(height: height, alignment: .bottom)
    }
}

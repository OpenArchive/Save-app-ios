//
//  MainBottomMenuView.swift
//  Save
//

import SwiftUI
import UIKit

struct MainBottomMenuView: View {

 
    private enum Metrics {
        static let horizontalInset: CGFloat = 24
        static let addWidth: CGFloat = 72
        static let addHeight: CGFloat = 34
        static let addCornerRadius: CGFloat = 16
        static let labelIconSpacing: CGFloat = 6
        static let barTopPadding: CGFloat = 20
        static let barBottomPadding: CGFloat = 20
        static let sideIconLength: CGFloat = 26
    }

    let isSettingsVisible: Bool
    let onTapMedia: () -> Void
    let onTapAdd: () -> Void
    let onLongPressAdd: () -> Void
    let onTapSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onTapMedia) {
                    VStack(spacing: Metrics.labelIconSpacing) {
                        Image(isSettingsVisible ? "media_unselected" : "media_image")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Metrics.sideIconLength, height: Metrics.sideIconLength)
                        Text(NSLocalizedString("My Media", comment: ""))
                            .font(.montserrat(.regular, for: .caption))
                    }
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: true)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onTapAdd) {
                    RoundedRectangle(cornerRadius: Metrics.addCornerRadius, style: .continuous)
                        .fill(Color.white)
                        .frame(width: Metrics.addWidth, height: Metrics.addHeight)
                        .overlay(
                            Image("ic_plus")
                                .foregroundColor(.black)
                        )
                }
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    onLongPressAdd()
                })

                Spacer()

                Button(action: onTapSettings) {
                    VStack(spacing: Metrics.labelIconSpacing) {
                        Image(systemName: isSettingsVisible ? "gearshape.fill" : "gearshape")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("Settings", comment: ""))
                            .font(.montserrat(.regular, for: .caption))
                    }
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.top, Metrics.barTopPadding)
        }
        .background(
            Color("menu-background")
                .clipShape(RoundedCorner(radius: 9, corners: [.topLeft, .topRight]))
        )
        .background(Color("menu-background").ignoresSafeArea(edges: .bottom))
    }
}

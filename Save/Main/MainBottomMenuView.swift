//
//  MainBottomMenuView.swift
//  Save
//

import SwiftUI
import UIKit

struct MainBottomMenuView: View {
    let isSettingsVisible: Bool
    let onTapMedia: () -> Void
    let onTapAdd: () -> Void
    let onLongPressAdd: () -> Void
    let onTapSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onTapMedia) {
                    VStack(spacing: 6) {
                        Image(isSettingsVisible ? "media_unselected" : "media_image")
                        Text(NSLocalizedString("My Media", comment: ""))
                            .font(.montserrat(.regular, for: .caption))
                    }
                    .foregroundColor(.white)
                }

                Spacer()

                Button(action: onTapAdd) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 72, height: 34)
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
                    VStack(spacing: 6) {
                        Image(systemName: isSettingsVisible ? "gearshape.fill" : "gearshape")
                        Text(NSLocalizedString("Settings", comment: ""))
                            .font(.montserrat(.regular, for: .caption))
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(
            Color("menu-background")
                .clipShape(RoundedCorner(radius: 9, corners: [.topLeft, .topRight]))
        )
        .background(Color("menu-background").ignoresSafeArea(edges: .bottom))
    }
}

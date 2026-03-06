//
//  MediaPopupView.swift
//  Save
//
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct MediaPopupView: View {

    var onCameraTap: () -> Void
    var onGalleryTap: () -> Void
    var onFilesTap: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Text(NSLocalizedString("Add media from", comment: ""))
                    .font(.montserrat(.semibold, for: .callout))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                HStack(spacing: 0) {
                    Spacer()

                    mediaOption(image: "camera",
                                label: NSLocalizedString("Camera", comment: ""),
                                action: onCameraTap)

                    Spacer()

                    mediaOption(image: "gallery",
                                label: NSLocalizedString("Photo Gallery", comment: ""),
                                action: onGalleryTap)

                    Spacer()

                    mediaOption(image: "doc",
                                label: NSLocalizedString("Files", comment: ""),
                                action: onFilesTap)

                    Spacer()
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(
                Color(.gray10)
                    .clipShape(RoundedCornerShape(radius: 20, corners: [.topLeft, .topRight]))
                    .ignoresSafeArea(.container, edges: .bottom)
            )
        }
    }

    private func mediaOption(image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)

                Text(label)
                    .font(.montserrat(.regular, for: .footnote))
                    .foregroundColor(Color(UIColor.label))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

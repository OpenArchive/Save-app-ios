//
//  DarkroomView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

struct DarkroomView: View {
    @StateObject private var viewModel: DarkroomViewModel
    @FocusState private var focusedField: MediaInfoField?
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)?
    var onRemoveAsset: (() -> Void)?

    init(initialIndex: Int = 0, onDismiss: (() -> Void)? = nil, onRemoveAsset: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: DarkroomViewModel(initialIndex: initialIndex))
        self.onDismiss = onDismiss
        self.onRemoveAsset = onRemoveAsset
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .bottom)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    imageSection(geometry: geometry)

                    infoSection
                        .frame(height: geometry.size.height * 0.5)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                    UIApplication.shared.endEditing()
                    viewModel.saveCurrentAssetInfo()
                }
            }
        }
        .onDisappear {
            viewModel.saveCurrentAssetInfo()
        }
        .onChange(of: viewModel.assets) { newAssets in
            if newAssets.isEmpty {
                onDismiss?()
            }
        }
    }

    @ViewBuilder
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            TabView(selection: $viewModel.selectedIndex) {
                ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                    assetImageView(asset: asset)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.selectedIndex) { newIndex in
                viewModel.onPageChange(to: newIndex)
            }

            imageOverlay
        }
        .frame(height: geometry.size.height * 0.5)
    }

    private var imageOverlay: some View {
        VStack {
            HStack {
                Text(viewModel.counterText)
                    .font(.montserrat(.semibold, for: .caption2))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.countLabel)
                    .cornerRadius(12)

                Spacer()

                FlagView(
                    isSelected: $viewModel.isFlagged,
                    unselectedColor: .white,
                    size: 20
                ) {
                    viewModel.toggleFlagged()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            HStack {
                Button(action: { viewModel.goBackward() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .opacity(viewModel.canGoBackward ? 1 : 0)
                .disabled(!viewModel.canGoBackward)
                .padding(.leading, 12)

                Spacer()

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .opacity(viewModel.canGoForward ? 1 : 0)
                .disabled(!viewModel.canGoForward)
                .padding(.trailing, 12)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func assetImageView(asset: Asset) -> some View {
        ZStack {
            if asset.hasThumbnail() {
                AsyncThumbnailView(asset: asset, fullQuality: true)
            } else {
                placeholderView(for: asset)
            }

            if asset.isAv {
                VStack {
                    Spacer()
                    HStack {
                        MovieIndicatorView(duration: asset.duration)
                            .padding(12)
                        Spacer()
                    }
                }
            }
        }
    }

    private func placeholderView(for asset: Asset) -> some View {
        ZStack {
            Color(UIColor.systemGray6)
            Image(asset.getFileType().placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
        }
    }

    private var infoSection: some View {
        MediaInfoSectionView(
            location: $viewModel.location,
            notes: $viewModel.notes,
            focusedField: $focusedField,
            onLocationChanged: { viewModel.updateLocation($0) },
            onNotesChanged: { viewModel.updateNotes($0) }
        )
    }
}

struct AsyncThumbnailView: View {
    let asset: Asset
    var fullQuality: Bool = false
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Color(UIColor.systemBackground)
                    .overlay(ProgressView().tint(.gray))
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        if fullQuality {
            loadFullImage()
        } else {
            asset.getThumbnailAsync { loadedThumbnail in
                DispatchQueue.main.async {
                    self.thumbnail = loadedThumbnail
                }
            }
        }
    }

    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Try loading the original file first
            if let fileURL = asset.file,
               let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
                return
            }
            // Fall back to thumbnail if full file unavailable
            asset.getThumbnailAsync { loadedThumbnail in
                DispatchQueue.main.async {
                    self.thumbnail = loadedThumbnail
                }
            }
        }
    }
}

struct ScrollDismissesKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

struct RoundedCorner: Shape {
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

#if DEBUG
struct DarkroomView_Previews: PreviewProvider {
    static var previews: some View {
        DarkroomView()
    }
}
#endif

//
//  MediaGridView.swift
//  Save
//
//  Created by navoda on 2026-03-23.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct MediaGridView: View {
    @ObservedObject var viewModel: MediaGridViewModel

    /// Called when user taps a "ready to upload" asset to open preview.
    var onSelectAsset: ((Asset) -> Void)?
    /// Called when user long-presses; caller may need to show select-media bar.
    var onLongPress: (() -> Void)?
    /// Called when user taps an asset with upload (error → show alert; else → present management).
    var onTapAssetWithUpload: ((Asset, Upload?) -> Void)?

    init(
        viewModel: MediaGridViewModel,
        onSelectAsset: ((Asset) -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onTapAssetWithUpload: ((Asset, Upload?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSelectAsset = onSelectAsset
        self.onLongPress = onLongPress
        self.onTapAssetWithUpload = onTapAssetWithUpload
    }

    private static let columns = 3
    private static let spacing: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            // Account for section insets (matching original UIKit implementation)
            let horizontalInset: CGFloat = 3 // Add inset to prevent border clipping
            let cellSize = (geometry.size.width - horizontalInset * 2 - CGFloat(Self.columns - 1) * Self.spacing) / CGFloat(Self.columns)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sections) { section in
                        sectionHeader(section: section)
                            .padding(.leading, 4)
                            .padding(.trailing, 4)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.fixed(cellSize), spacing: Self.spacing),
                                count: Self.columns
                            ),
                            spacing: Self.spacing
                        ) {
                            ForEach(section.assets, id: \.id) { asset in
                                MediaGridCellView(
                                    asset: asset,
                                    upload: viewModel.upload(for: asset.id),
                                    isSelected: viewModel.selectedAssetIds.contains(asset.id),
                                    cellSize: cellSize,
                                    onTap: { handleTap(asset: asset, upload: viewModel.upload(for: asset.id)) },
                                    onLongPress: { handleLongPress(asset: asset) }
                                )
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func sectionHeader(section: MediaGridSection) -> some View {
        HStack(spacing: 8) {
            Text(headerText(for: section.collection))
                .font(.montserrat(.regular, for: .caption))
                .foregroundColor(Color(.label))

            Spacer(minLength: 0)

            Text(headerCountText(for: section.collection))
                .font(.montserrat(.regular, for: .caption))
                .foregroundColor(Color(.label))
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(.pillBackground))
                )
        }
    }

    private func headerText(for collection: Collection?) -> String {
        guard let collection = collection else { return "" }
        if let uploadedTs = collection.uploaded, collection.waitingAssetsCount == 0 {
            let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)
            return fiveMinAgo < uploadedTs
                ? NSLocalizedString("Just now", comment: "")
                : Formatters.format(uploadedTs)
        }
        if collection.closed != nil {
            return collection.uploadedAssetsCount == 0
                ? NSLocalizedString("Waiting…", comment: "")
                : NSLocalizedString("Uploading…", comment: "")
        }
        return NSLocalizedString("Ready to upload", comment: "")
    }

    private func headerCountText(for collection: Collection?) -> String {
        guard let collection = collection else { return "" }
        if let _ = collection.uploaded, collection.waitingAssetsCount == 0 {
            return "  \(Formatters.format(collection.uploadedAssetsCount))  "
        }
        if collection.closed != nil {
            let total = collection.assets.count
            let uploaded = collection.uploadedAssetsCount
            return String(
                format: "  \(NSLocalizedString("%1$@/%2$@", comment: "both are integer numbers meaning 'x of n'"))  ",
                Formatters.format(uploaded),
                Formatters.format(total)
            )
        }
        return "  \(Formatters.format(collection.waitingAssetsCount))  "
    }

    private func handleTap(asset: Asset, upload: Upload?) {
        if viewModel.isInEditMode {
            viewModel.toggleSelection(asset.id)
            return
        }
        if upload != nil {
            onTapAssetWithUpload?(asset, upload)
            return
        }
        if asset.isUploaded {
            viewModel.enterEditMode(selecting: asset.id)
            onLongPress?()  // Show select-media bar
            return
        }
        onSelectAsset?(asset)
    }

    private func handleLongPress(asset: Asset) {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        viewModel.enterEditMode(selecting: asset.id)
        onLongPress?()  // Caller shows select-media bar
    }
}

private struct MediaGridCellView: View {
    let asset: Asset
    let upload: Upload?
    let isSelected: Bool
    let cellSize: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var thumbnail: UIImage?
    @State private var currentAssetId: String?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var showUploadOverlay: Bool {
        guard !(asset.isUploaded) else { return false }
        guard let upload = upload else { return false }
        return upload.state == .uploading || upload.state == .pending
    }

    private var showErrorIcon: Bool {
        upload?.error != nil
    }

    var body: some View {
        ZStack {
            contentView
            if !asset.isUploaded && !reduceTransparency {
                        if upload?.state == .uploading || upload?.state == .pending, upload?.error == nil {
                            // Dark blur for active upload
                            BlurOverlayView(style: .dark, alpha: 0.65)
                        } else if upload == nil {
                            // Light blur for ready to upload
                            BlurOverlayView(style: .extraLight, alpha: 0.35)
                        }
                    }
            
            // Movie indicator bar at bottom
            if asset.isAv {
                VStack {
                    Spacer()
                    MovieIndicatorView(duration: asset.duration)
                }
            }
            
            // Progress overlay (centered)
            if showUploadOverlay {
                uploadProgressOverlay
            }
            
            // Error icon in top-right corner
            if showErrorIcon {
                VStack {
                    HStack {
                        Spacer()
                        errorIconOverlay
                    }
                    Spacer()
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(Color.accent, lineWidth: isSelected ? 5 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: asset.id) { _ in
            thumbnail = nil
            currentAssetId = nil
            loadThumbnail()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if asset.hasThumbnail() {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
                    .frame(width: cellSize, height: cellSize)
            }
        } else {
            defaultFileTypeView
        }
    }

    private var defaultFileTypeView: some View {
        ZStack {
            // Background fills entire cell
            Color(.placeholderBackground)
            
            // Centered content
            VStack(spacing: 8) {
                Image(asset.getFileType().placeholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(Color(.placeholderFile))
                
                if !asset.filename.isEmpty {
                    Text(asset.filename)
                        .font(.montserrat(.regular, for: .caption))
                        .foregroundColor(Color(.label))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private struct BlurOverlayView: UIViewRepresentable {
        let style: UIBlurEffect.Style
        let alpha: CGFloat

        func makeUIView(context: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
            view.alpha = alpha
            return view
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
            uiView.alpha = alpha
        }
    }

    private var uploadProgressOverlay: some View {
        ZStack {
            let isUploading = upload?.state == .uploading
            Color.black.opacity(isUploading ? 0.5 : 0.2)
            MediaGridProgressView(
                state: upload?.state ?? .pending,
                progress: upload?.progress ?? 0
            )
            .frame(width: 24, height: 24)
        }
        .frame(width: cellSize, height: cellSize)
    }

    private var errorIconOverlay: some View {
        Image("ic_error")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.redButton)
            .padding(8)
    }

    private func loadThumbnail() {
        guard asset.hasThumbnail() else { return }
        let assetId = asset.id
        currentAssetId = assetId
        asset.getThumbnailAsync { loadedThumbnail in
            DispatchQueue.main.async {
                guard self.currentAssetId == assetId else { return }
                self.thumbnail = loadedThumbnail
            }
        }
    }
}


/// Accent circle like UploadRow: hollow when pending, fills when uploading. Centered.
private struct MediaGridProgressView: View {
    let state: Upload.State
    let progress: Double

    @State private var animationProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accent.opacity(0.3), lineWidth: 2)
            switch state {
            case .pending:
                Circle()
                    .trim(from: animationProgress, to: animationProgress + 0.3)
                    .stroke(Color.accent, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            animationProgress = 1
                        }
                    }
            case .uploading:
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1)))
                    .stroke(Color.accent, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
            default:
                Circle()
                    .stroke(Color.accent, lineWidth: 2)
            }
        }
    }
}

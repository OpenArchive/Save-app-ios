//
//  MediaGridView.swift
//  Save
//
//  Created by navoda on 2026-03-23.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

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
    private static let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

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
                                let upload = viewModel.upload(for: asset.id)
                                MediaGridCellView(
                                    asset: asset,
                                    collection: section.collection,
                                    upload: upload,
                                    isSelected: viewModel.selectedAssetIds.contains(asset.id),
                                    cellSize: cellSize,
                                    onTap: { handleTap(asset: asset, upload: upload, collection: section.collection) },
                                    onLongPress: { handleLongPress(asset: asset) }
                                )
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                    }
                }
                .padding(.bottom, 8)
            }
            .onAppear {
                Self.impactFeedback.prepare()
            }
        }
    }

    private func sectionHeader(section: MediaGridSection) -> some View {
        HStack(spacing: 8) {
            Text(headerText(for: section))
                .font(.montserrat(.regular, for: .caption))
                .foregroundColor(Color(.label))

            Spacer(minLength: 0)

            Text(headerCountText(for: section))
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

    private func headerText(for section: MediaGridSection) -> String {
        let collection = section.collection
        guard let collection = collection else { return "" }

        let uploadedCount = section.assets.filter(\.isUploaded).count
        let totalCount = section.assets.count
        let allUploaded = totalCount > 0 && uploadedCount == totalCount

        if allUploaded, let uploadedTs = collection.uploaded {
            let fiveMinAgo = Date(timeIntervalSinceNow: -5 * 60)
            return fiveMinAgo < uploadedTs
                ? NSLocalizedString("Just now", comment: "")
                : Formatters.format(uploadedTs)
        }
        if collection.closed != nil {
            let hasActiveUpload = section.assets.contains { asset in
                viewModel.upload(for: asset.id)?.state == .uploading
            }
            let hasStartedUploading = hasActiveUpload || uploadedCount > 0
            return hasStartedUploading
                ? NSLocalizedString("Uploading…", comment: "")
                : NSLocalizedString("Waiting…", comment: "")
        }
        return NSLocalizedString("Ready to upload", comment: "")
    }

    private func headerCountText(for section: MediaGridSection) -> String {
        guard let collection = section.collection else { return "" }

        let uploadedCount = section.assets.filter(\.isUploaded).count
        let totalCount = section.assets.count
        let allUploaded = totalCount > 0 && uploadedCount == totalCount

        if allUploaded, collection.uploaded != nil {
            return "  \(Formatters.format(uploadedCount))  "
        }
        if collection.closed != nil {
            return String(
                format: "  \(NSLocalizedString("%1$@/%2$@", comment: "both are integer numbers meaning 'x of n'"))  ",
                Formatters.format(uploadedCount),
                Formatters.format(totalCount)
            )
        }
        let waitingCount = section.assets.filter { !$0.isUploaded }.count
        return "  \(Formatters.format(waitingCount))  "
    }

    private func handleTap(asset: Asset, upload: Upload?, collection: Collection?) {
        if viewModel.isInEditMode {
            viewModel.toggleSelection(asset.id)
            return
        }
        let isInUploadPipeline = !asset.isUploaded && (upload != nil || collection?.closed != nil)
        if isInUploadPipeline {
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
        Self.impactFeedback.impactOccurred()
        
        viewModel.enterEditMode(selecting: asset.id)
        onLongPress?()  // Caller shows select-media bar
    }
}

private struct MediaGridCellView: View {
    let asset: Asset
    let collection: Collection?
    let upload: Upload?
    let isSelected: Bool
    let cellSize: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var thumbnail: UIImage?
    @State private var currentAssetId: String?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Folder not yet queued — light blur only in this state.
    private var isReadyToUpload: Bool {
        !asset.isUploaded && collection?.closed == nil && upload == nil
    }

    /// Queued or actively uploading — dark blur + progress ring until the asset is uploaded.
    private var isInUploadPipeline: Bool {
        !asset.isUploaded && (collection?.closed != nil || upload != nil)
    }

    private var showActiveUploadUI: Bool {
        guard !asset.isUploaded else { return false }
        if let upload = upload {
            return upload.error == nil
        }
        // Closed batch with no upload row yet (e.g. right after tapping Upload).
        return collection?.closed != nil
    }

    private var showErrorIcon: Bool {
        upload?.error != nil
    }

    private var resolvedUploadState: Upload.State {
        if upload?.paused == true { return .paused }
        if (upload?.progress ?? 0) >= 1 { return .uploading }
        return upload?.state ?? .pending
    }

    private var resolvedProgress: Double {
        min(upload?.progress ?? 0, 1)
    }

    var body: some View {
        ZStack {
            contentView
            if !asset.isUploaded && !reduceTransparency {
                if showActiveUploadUI {
                    BlurOverlayView(style: .dark, alpha: 0.65)
                } else if isReadyToUpload {
                    BlurOverlayView(style: .extraLight, alpha: 0.35)
                }
            }
            
            if asset.isAv {
                VStack {
                    Spacer()
                    MovieIndicatorView(duration: asset.duration)
                }
            }
            
            if showErrorIcon {
                errorIconOverlay
            } else if showActiveUploadUI {
                uploadProgressOverlay
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
        .onDisappear {
            // Drop decoded image when off-screen to cap memory during fast scroll.
            thumbnail = nil
            currentAssetId = nil
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
            let isUploading = resolvedUploadState == .uploading
            Color.black.opacity(isUploading ? 0.5 : 0.2)
            MediaGridProgressView(
                state: resolvedUploadState,
                progress: resolvedProgress
            )
            .frame(width: 24, height: 24)
        }
        .frame(width: cellSize, height: cellSize)
    }

    private var errorIconOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
            Image("ic_error")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundColor(.redButton)
        }
        .frame(width: cellSize, height: cellSize)
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

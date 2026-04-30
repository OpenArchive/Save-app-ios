//
//  PreviewCellView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct PreviewCellView: View {
    let asset: Asset
    let isSelected: Bool
    let refreshId: UUID
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var thumbnail: UIImage?
    @State private var currentAssetId: String?
    @State private var loadFailed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                contentView(size: geometry.size)
                
                if asset.isAv {
                    movieIndicatorOverlay
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .overlay(
                Rectangle()
                    .stroke(Color.accent, lineWidth: isSelected ? 10 : 0)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
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
        .onChange(of: asset.id) { newId in
            thumbnail = nil
            currentAssetId = nil
            loadFailed = false
            loadThumbnail()
        }
        .onChange(of: refreshId) { _ in
            if thumbnail == nil && asset.hasThumbnail() {
                loadThumbnail()
            }
        }
    }
    
    @ViewBuilder
    private func contentView(size: CGSize) -> some View {
        if asset.hasThumbnail() {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.width)
                    .clipped()
            } else if loadFailed {
                Image("NoImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.width)
                    .clipped()
            } else {
                Color(.systemGray6)
                    .frame(width: size.width, height: size.width)
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            }
        } else {
            defaultFileTypeView
                .frame(width: size.width, height: size.width)
        }
    }
    
    private var defaultFileTypeView: some View {
        VStack(spacing: 8) {
            Image(asset.getFileType().placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            
            Text(asset.filename)
                .font(.montserrat(.regular, for: .caption2))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private var movieIndicatorOverlay: some View {
        VStack {
            Spacer()
            MovieIndicatorView(duration: asset.duration)
        }
    }
    
    private func loadThumbnail() {
        guard asset.hasThumbnail() else { return }

        let assetId = asset.id
        currentAssetId = assetId

        asset.getThumbnailAsync { loadedThumbnail in
            DispatchQueue.main.async {
                guard self.currentAssetId == assetId else { return }
                if let image = loadedThumbnail {
                    self.thumbnail = image
                } else {
                    self.loadFailed = true
                }
            }
        }
    }
}

#if DEBUG
struct PreviewCellView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Preview not available - requires Asset object")
        }
    }
}
#endif

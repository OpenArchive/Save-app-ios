//
//  BatchEditView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct BatchEditView: View {
    @State var assets: [Asset]
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isFlagged: Bool = false
    @FocusState private var focusedField: MediaInfoField?

    var onDismiss: (() -> Void)?

    private enum Layout {
        static let imageSectionHeightFraction: CGFloat = 0.6
        static let infoSectionHeightFraction: CGFloat = 0.4
        static let cardHorizontalOffset: CGFloat = 31
        static let cardVerticalOffset: CGFloat = 28
        static let cardWidthFraction: CGFloat = 0.70
    }

    init(assets: [Asset], onDismiss: (() -> Void)? = nil) {
        self._assets = State(initialValue: assets)
        self.onDismiss = onDismiss

        let initialFlagged = assets.allSatisfy { $0.flagged }
        self._isFlagged = State(initialValue: initialFlagged)

        if let firstAsset = assets.first {
            self._location = State(initialValue: firstAsset.location ?? "")
            self._notes = State(initialValue: firstAsset.notes ?? "")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                imageSection(geometry: geometry)

                infoSection
                    .frame(height: geometry.size.height * Layout.infoSectionHeightFraction)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onTapGesture {
            focusedField = nil
        }
    }

    // MARK: - Image section

    // In imageSection, pass geometry before padding:
    @ViewBuilder
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            stackedImagesView(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height
            )
            .padding(.leading, 35)
            .padding(.top, 40)

            imageOverlay
        }
        .frame(height: geometry.size.height * Layout.imageSectionHeightFraction)
        .background(Color(UIColor.systemBackground))
        .clipped()
    }

    @ViewBuilder
    private func stackedImagesView(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let displayAssets = Array(assets.prefix(3))

        if displayAssets.isEmpty {
            Color.black
                .overlay(
                    Image("unknown")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                )
        } else {
            let leadingInset: CGFloat = 35
            let sectionHeight = screenHeight * Layout.imageSectionHeightFraction
            let topInset: CGFloat    = 40

            // Container size = screen minus insets (matches storyboard green view)
            let containerWidth  = screenWidth  - leadingInset  // container trailing = screen trailing
            let containerHeight = sectionHeight - topInset

            let stepX: CGFloat       = 31
            let stepY: CGFloat       = 27.5
            let numSteps: CGFloat    = 2
            let trailingPad: CGFloat = 30  // image3 trailing to container
            let bottomPad: CGFloat   = 20  // image3 bottom to container

            let cardWidth  = containerWidth  - (numSteps * stepX) - trailingPad
            let cardHeight = containerHeight - (numSteps * stepY) - bottomPad

            GeometryReader { _ in
                ForEach(Array(displayAssets.prefix(3).enumerated()), id: \.element.id) { index, asset in
                    batchCardContent(for: asset)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .position(
                            x: (CGFloat(index) * stepX) + cardWidth / 2,
                            y: (CGFloat(index) * stepY) + cardHeight / 2
                        )
                        .zIndex(Double(index))
                }
            }
            .frame(width: containerWidth, height: containerHeight)
        }
    }
    private var imageOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Formatters.format(assets.count))
                    .font(.montserrat(.semibold, for: .caption2))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.countLabel)
                    .clipShape(Capsule())

                Spacer()

                FlagView(
                    isSelected: $isFlagged,
                    unselectedColor: .white,
                    size: 20
                ) {
                    toggleFlagged()
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(.clear)

            Spacer()
        }
    }
 

    @ViewBuilder
    private func batchCardContent(for asset: Asset) -> some View {
        ZStack {
            if asset.hasThumbnail() {
                AsyncThumbnailView(asset: asset)
                    .aspectRatio(contentMode: .fill)
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

    // MARK: - Info section

    private var infoSection: some View {
        MediaInfoSectionView(
            location: $location,
            notes: $notes,
            focusedField: $focusedField,
            onLocationChanged: { newValue in updateAssets { $0.location = newValue } },
            onNotesChanged: { newValue in updateAssets { $0.notes = newValue } }
        )
    }

    // MARK: - Helpers

    private func toggleFlagged() {
        isFlagged.toggle()
        updateAssets { $0.flagged = isFlagged }
        FlagInfoAlert.presentIfNeeded()
    }

    private func updateAssets(_ update: @escaping (AssetProxy) -> Void) {
        Asset.update(assets: assets, update) { [self] updatedAssets in
            self.assets = updatedAssets
        }
    }
}

#if DEBUG
struct BatchEditView_Previews: PreviewProvider {
    static var previews: some View {
        BatchEditView(assets: [])
    }
}
#endif

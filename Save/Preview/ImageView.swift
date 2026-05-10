//
//  ImageView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct ImageView: View {
    let image: UIImage?
    let placeholderImage: UIImage?
    let isThumbnail: Bool
    let isAv: Bool
    let duration: TimeInterval?
    let index: Int
    
    init(
        image: UIImage? = nil,
        placeholderImage: UIImage? = nil,
        isThumbnail: Bool = false,
        isAv: Bool = false,
        duration: TimeInterval? = nil,
        index: Int = 0
    ) {
        self.image = image
        self.placeholderImage = placeholderImage
        self.isThumbnail = isThumbnail
        self.isAv = isAv
        self.duration = duration
        self.index = index
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isThumbnail {
                    thumbnailView
                } else {
                    placeholderView
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .bottom) {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            
            if isAv {
                MovieIndicatorView(duration: duration)
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        if let placeholder = placeholderImage {
            Image(uiImage: placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Color(.placeholderFile))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.placeholderBackground))
        } else {
            Color(.placeholderBackground)
        }
    }
}

#if DEBUG
struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ImageView(
                image: UIImage(systemName: "photo"),
                isThumbnail: true,
                isAv: true,
                duration: 125.5,
                index: 0
            )
            .frame(width: 200, height: 200)
            .clipped()
            
            ImageView(
                placeholderImage: UIImage(named: "unknown"),
                isThumbnail: false,
                index: 1
            )
            .frame(width: 200, height: 200)
        }
    }
}
#endif

//
//  MovieIndicatorView.swift
//  Save
//
//  Created by navoda on 2026-03-23.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

/// A view that displays a video/audio duration indicator, typically overlaid on media thumbnails.
/// Duration label overlay for video thumbnails (same layout as the legacy UIKit indicator).
struct MovieIndicatorView: View {
    let duration: TimeInterval?
    
    var body: some View {
        HStack(spacing: 4) {
            // Video icon on left
            Image("video")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
            
            Spacer()
            
            // Duration on right corner
            if let duration = duration, duration > 0 {
                Text(Formatters.format(duration))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.6))
        )
    }
}

#if DEBUG
struct MovieIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Short video
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.3)
                MovieIndicatorView(duration: 25)
            }
            .frame(width: 150, height: 150)
            .previewDisplayName("0:25")
            
            // Medium video
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.3)
                MovieIndicatorView(duration: 185)
            }
            .frame(width: 150, height: 150)
            .previewDisplayName("3:05")
            
            // Long video
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.3)
                MovieIndicatorView(duration: 3725)
            }
            .frame(width: 150, height: 150)
            .previewDisplayName("1:02:05")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif

//
//  FileGridItemView.swift
//  Save
//
//  Created by navoda on 2025-09-17.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

// MARK: - Individual File Grid Item
struct FileGridItemView: View {
    let upload: StorachaUploadItem
    @State private var fileMetadata: FileMetadata?
    @State private var isLoading = false
    
    private let metadataFetcher = FileMetadataFetcher.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let metadata = fileMetadata {
                    if metadata.fileType == .image {
                        AsyncImage(url: URL(string: metadata.directUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.8)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                Image(metadata.fileType.systemIconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(metadata.fileType.systemIconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                } else {
                    Image(FileType.unknown.systemIconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 2) {
                Text(displayName)
                    .font(.montserrat(.medium, for: .caption))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 100)
        .task(id: upload.cid) { 
            await loadMetadata()
        }
        .onTapGesture {
            handleTap()
        }
    }
    
    private var displayName: String {
        if let metadata = fileMetadata {
            return metadata.fileName
        } else {
            return upload.cid.prefix(12) + "..."
        }
    }
    
    private func loadMetadata() async {
        // Check cache first (synchronous, no await needed)
        if let cached = metadataFetcher.getCachedMetadata(for: upload.gatewayUrl) {
            self.fileMetadata = cached
            return
        }
        
        // Already loaded
        if fileMetadata != nil {
            return
        }
        
        isLoading = true
        
        if let metadata = await metadataFetcher.fetchFileMetadata(from: upload.gatewayUrl) {
            self.fileMetadata = metadata
            self.isLoading = false
        } else {
            self.isLoading = false
        }
    }
    
    private func handleTap() {
        if let metadata = fileMetadata,
           let url = URL(string: metadata.directUrl) {
            UIApplication.shared.open(url)
        } else {
            if let url = URL(string: "https://gateway.storacha.network/ipfs/\(upload.cid)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

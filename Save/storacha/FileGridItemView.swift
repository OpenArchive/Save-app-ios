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
    @StateObject private var metadataFetcher = FileMetadataFetcher()
    @State private var fileMetadata: FileMetadata?
    @State private var isLoading = true
    
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
                        AsyncImage(url: URL(string: metadata.directUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(metadata.fileType.systemIconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // File type icon
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
            
            // File Name
            VStack(spacing: 2) {
                Text(displayName)
                    .font(.montserrat(.medium, for: .caption))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 100)
        .task {
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
        isLoading = true
        
        if let metadata = await metadataFetcher.fetchFileMetadata(from: upload.gatewayUrl) {
            await MainActor.run {
                self.fileMetadata = metadata
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func handleTap() {
        if let metadata = fileMetadata,
           let url = URL(string: metadata.directUrl) {
            UIApplication.shared.open(url)
        } else {
            // Fallback - open with CID
            if let url = URL(string: "https://gateway.storacha.network/ipfs/\(upload.cid)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

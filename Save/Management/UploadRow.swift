//
//  UploadRow.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct UploadRow: View {
    let upload: Upload
    let onDelete: () -> Void
    let onShowError: () -> Void
    
    private var showProgress: Bool {
        upload.error == nil && upload.state != .uploaded
    }
    
    private var showError: Bool {
        upload.error != nil
    }
    
    private var showDone: Bool {
        upload.state == .uploaded
    }
    
    private var sizeText: String {
        if !(upload.isReady) && upload.state != .uploaded {
            return NSLocalizedString("Encoding file…", comment: "")
        }
        
        let total = upload.asset?.filesize ?? 0
        let done = Double(total) * (upload.progress - 0.1) / 0.9
        
        if done > 0 {
            return "\(Formatters.formatByteCount(total)) – ↑\(Formatters.formatByteCount(Int64(done)))"
        }
        return Formatters.formatByteCount(total)
    }
    
    var body: some View {
        VStack(spacing: 0) {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onDelete) {
                Image("trash_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)
            
            ZStack {
                thumbnailView
                    .frame(width: 50, height: 50)
                    .cornerRadius(4)
                    .padding(.vertical, 6)
                
                if showProgress {
                    ProgressButtonView(
                        state: upload.state,
                        progress: upload.progress
                    )
                    .frame(width: 24, height: 24)
                }
                
                if showError || showDone {
                    statusView
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(upload.filename)
                    .font(.montserrat(.medium, for: .subheadline))
                    .lineLimit(2)
                    .foregroundColor(Color(UIColor.label))

                Text(sizeText)
                    .font(.montserrat(.regular, for: .caption))
                    .foregroundColor(Color(.gray70))
            }
            .padding(.trailing, 8)

            Spacer()
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 75)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if upload.asset?.hasThumbnail() ?? false, let thumbnail = upload.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            let placeholder = upload.asset?.getFileType().placeholder ?? "unknown"
            Image(placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        if showError {
            Button(action: onShowError) {
                Image("ic_error")
                    .foregroundColor(.redButton)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        } else if showDone {
            Image("check-mark")
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
        }
    }
}

struct ProgressButtonView: View {
    let state: Upload.State
    let progress: Double
    
    @State private var animationProgress: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
            
            switch state {
            case .paused:
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            case .pending:
                Circle()
                    .trim(from: animationProgress, to: animationProgress + 0.3)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            animationProgress = 1
                        }
                    }
            case .uploading:
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
            case .uploaded:
                Circle()
                    .stroke(Color.green, lineWidth: 2)
            }
        }
    }
}

#if DEBUG
struct UploadRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Preview not available - requires Upload object")
                .padding()
        }
    }
}
#endif

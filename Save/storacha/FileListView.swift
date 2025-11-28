import SwiftUI

struct FileListView: View {
    @EnvironmentObject var spaceState: SpaceState
    let spaceDid: String
    let onUploadTapped: () -> Void
    let isSpaceAdmin: Bool
    
    @State private var isLoadingMore = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                fileListContent
            }
            
            if !spaceState.isUploading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        uploadButton
                        Spacer()
                    }
                }
            }
            
            if spaceState.isUploading {
                uploadingOverlay
            }
            
            if let result = spaceState.uploadResult {
                uploadResultOverlay(result: result)
            }
        }
        .compatTask {
            await spaceState.loadUploads(for: spaceDid, isAdmin: isSpaceAdmin, reset: true)
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var fileListContent: some View {
        if spaceState.isLoadingUploads && spaceState.uploads.isEmpty {
            loadingView
        } else if spaceState.uploads.isEmpty && !spaceState.isLoadingUploads {
            emptyView
        } else {
            fileGridView
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView(NSLocalizedString("Loading files...", comment: ""))
                .font(.montserrat(.medium, for: .body))
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack {
            Spacer()
            Text(NSLocalizedString("No Media Available", comment: ""))
                .foregroundColor(.gray)
                .font(.montserrat(.medium, for: .body))
            Spacer()
        }
    }
    
    private var fileGridView: some View {
        ScrollView {
            fileGridContent
        }
        .refreshable {
            if !spaceState.isUploading {
                await spaceState.loadUploads(for: spaceDid, isAdmin: isSpaceAdmin, reset: true)
            }
        }
    }
    
    private var fileGridContent: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 20
        ) {
            fileGridItems
            
            if shouldShowLoadingMore {
                loadingMoreView
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    }
    
    @ViewBuilder
    private var fileGridItems: some View {
        let uniqueUploadIds = Array(Set(spaceState.uploads.map { $0.id })).sorted()
        
        ForEach(uniqueUploadIds, id: \.self) { uploadId in
            if let upload = spaceState.uploads.first(where: { $0.id == uploadId }) {
                FileGridItemView(upload: upload)
                    .onAppear {
                        loadMoreIfNeeded(currentUpload: upload)
                    }
            }
        }
    }
    
    private var shouldShowLoadingMore: Bool {
        spaceState.isLoadingUploads && !spaceState.uploads.isEmpty && !spaceState.isUploading
    }
    
    // MARK: - Overlay Views
    
    private var uploadingOverlay: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea(.all)
            .allowsHitTesting(true)
            .overlay(
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text(NSLocalizedString("Uploading...", comment: ""))
                        .font(.montserrat(.medium, for: .callout))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            )
    }
    
    @ViewBuilder
    private func uploadResultOverlay(result: Result<UploadResponse, Error>) -> some View {
        Color.black.opacity(0.7)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                uploadResultAlert(result: result)
            )
    }
    
    @ViewBuilder
    private func uploadResultAlert(result: Result<UploadResponse, Error>) -> some View {
        switch result {
        case .success(let response):
            CustomAlertView(
                title: NSLocalizedString("Success!", comment: ""),
                message: NSLocalizedString("File uploaded successfully!\nCID: \(response.cid)\nSize: \(ByteCountFormatter.string(fromByteCount: Int64(response.size), countStyle: .file))", comment: ""),
                primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                iconImage: Image("check_icon"),
                primaryButtonAction: {
                    spaceState.resetUploadState()
                },
                showCheckbox: false
            )
            
        case .failure(let error):
            CustomAlertView(
                title: NSLocalizedString("Upload Failed", comment: ""),
                message: getErrorMessage(from: error),
                primaryButtonTitle: NSLocalizedString("OK", comment: ""),
                iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                iconTint: .red,
                primaryButtonAction: {
                    spaceState.resetUploadState()
                },
                showCheckbox: false
            )
        }
    }

    private func getErrorMessage(from error: Error) -> String {
        if let bridgeError = error as? BridgeUploadError {
            return bridgeError.localizedDescription
        } else if let apiError = error as? StorachaAPIError {
            return apiError.localizedDescription
        } else {
            return error.localizedDescription
        }
    }
    
    @ViewBuilder
    private var loadingMoreView: some View {
        if #available(iOS 16.0, *) {
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text(NSLocalizedString("Loading more...", comment: ""))
                    .font(.montserrat(.medium, for: .caption))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .gridCellColumns(3)
        } else {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("Loading more...", comment: ""))
                        .font(.montserrat(.medium, for: .caption))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 16)
        }
    }
    
    private var uploadButton: some View {
        Button(action: onUploadTapped) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.montserrat(.semibold, for: .headline))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    
    private func loadMoreIfNeeded(currentUpload: StorachaUploadItem) {
        guard !spaceState.isUploading,
              !isLoadingMore,
              let lastUpload = spaceState.uploads.last,
              currentUpload.id == lastUpload.id,
              spaceState.uploadsHasMore,
              !spaceState.isLoadingUploads else {
            return
        }
        
        isLoadingMore = true
        
        Task {
            await spaceState.loadUploads(for: spaceDid, isAdmin: isSpaceAdmin)
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoadingMore = false
        }
    }
}

import SwiftUI

@available(iOS 14.0, *)
struct FileListView: View {
    @EnvironmentObject var spaceState: SpaceState
    let spaceDid: String
    let onUploadTapped: () -> Void
    let isSpaceAdmin:Bool
    
    var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                fileListContent
            }
            
            // Upload Button - Hide during upload
            if !spaceState.isUploading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        uploadButton
                    }
                }
            }
            
            if spaceState.isUploading {
                
                Color.black.opacity(0.7)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(true)
                
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if let result = spaceState.uploadResult {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            uploadResultAlert(result: result)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    )
            }
        }
        .compatTask {
            // Load uploads when view appears
            await spaceState.loadUploads(for: spaceDid, isAdmin: isSpaceAdmin, reset: true)
        }
    }
    
    @ViewBuilder
    private func uploadResultAlert(result: Result<UploadResponse, Error>) -> some View {
        switch result {
        case .success(_):
            CustomAlertView(
                title: NSLocalizedString("Success!", comment: ""),
                message: NSLocalizedString("File uploaded successfully!", comment: ""),
                primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                iconImage: Image("check_icon"),
                primaryButtonAction: {
                    spaceState.resetUploadState()
                    // No need to reload here - already done in uploadFile
                },
                showCheckbox: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .failure(let error):
            CustomAlertView(
                title: NSLocalizedString("Upload Failed", comment: ""),
                message: "\(error.localizedDescription)",
                primaryButtonTitle: NSLocalizedString("Try Again", comment: ""),
                iconImage: Image(systemName: "exclamationmark.triangle.fill"),
                iconTint: .red,
                primaryButtonAction: {
                    spaceState.resetUploadState()
                },
                showCheckbox: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var fileListContent: some View {
        if spaceState.isLoadingUploads && spaceState.uploads.isEmpty {
            VStack {
                Spacer()
                ProgressView(NSLocalizedString("Loading files...", comment: ""))
                    .font(.montserrat(.medium, for: .body))
                Spacer()
            }
        } else if spaceState.uploads.isEmpty && !spaceState.isLoadingUploads {
            VStack {
                Spacer()
                
                Text(NSLocalizedString("No Media Available", comment: ""))
                    .foregroundColor(.gray)
                    .font(.montserrat(.medium, for: .body))
                
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                    spacing: 20
                ) {
                    // Use Set to track seen IDs and prevent duplicates
                    ForEach(Array(Set(spaceState.uploads.map { $0.id })).sorted(), id: \.self) { uploadId in
                        if let upload = spaceState.uploads.first(where: { $0.id == uploadId }) {
                            FileGridItemView(upload: upload)
                                .onAppear {
                                    
                                    if !spaceState.isUploading,
                                       let lastUpload = spaceState.uploads.last,
                                       upload.id == lastUpload.id,
                                       spaceState.uploadsHasMore,
                                       !spaceState.isLoadingUploads {
                                        Task {
                                            await spaceState.loadUploads(for: spaceDid,isAdmin: isSpaceAdmin)
                                        }
                                    }
                                }
                        }
                    }
                    
                    if spaceState.isLoadingUploads && !spaceState.uploads.isEmpty && !spaceState.isUploading {
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
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                if !spaceState.isUploading {
                    await spaceState.loadUploads(for: spaceDid,isAdmin: isSpaceAdmin, reset: true)
                }
            }
        }
    }
    
    @ViewBuilder
    private var uploadButton: some View {
        Button(action: onUploadTapped) {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(16)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 3)
        }
        .padding()
    }
}

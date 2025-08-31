import SwiftUI

@available(iOS 14.0, *)
struct FileListView: View {
    @EnvironmentObject var spaceState: SpaceState
    let spaceDid: String
    let onUploadTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            if spaceState.isLoadingUploads && spaceState.uploads.isEmpty {
                VStack {
                    ProgressView("Loading files...").font(.montserrat(.medium, for: .caption))
                        .padding(.top, 40)
                    Spacer()
                }
            } else if spaceState.uploads.isEmpty {
                VStack {
                    Text("No files available")
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                        .font(.montserrat(.medium, for: .body))
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(spaceState.uploads.enumerated()), id: \.element.id) { index, upload in
                        fileRow(for: upload)
                            .onAppear {
                                if index == spaceState.uploads.count - 1,
                                   spaceState.uploadsHasMore,
                                   !spaceState.isLoadingUploads {
                                    Task {
                                        await spaceState.loadUploads(for: spaceDid)
                                    }
                                }
                            }
                    }
                    if spaceState.isLoadingUploads && !spaceState.uploads.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
            
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
        .compatTask {
            await spaceState.loadUploads(for: spaceDid, reset: true)
        }
    }
}

// MARK: - Row Builder with version check
@ViewBuilder
private func fileRow(for upload: StorachaUploadItem) -> some View {
    HStack {
        Image(systemName: "doc.fill")
            .resizable()
            .frame(width: 30, height: 30)
            .foregroundColor(.accentColor)
            .padding(.trailing, 8)
        Text(upload.cid)
            .font(.montserrat(.medium, for: .body))
        Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal)
    .background(Color(.systemBackground))
    .modifier(HideSeparatorIfAvailable())
}
struct HideSeparatorIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.listRowSeparator(.hidden)
        } else {
            content // iOS 14 fallback → do nothing
        }
    }
}

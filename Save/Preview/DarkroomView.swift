//
//  DarkroomView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct DarkroomView: View {
    @StateObject private var viewModel: DarkroomViewModel
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    
    var onDismiss: (() -> Void)?
    var onRemoveAsset: (() -> Void)?
    
    enum Field {
        case location
        case notes
    }
    
    init(initialIndex: Int = 0, onDismiss: (() -> Void)? = nil, onRemoveAsset: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: DarkroomViewModel(initialIndex: initialIndex))
        self.onDismiss = onDismiss
        self.onRemoveAsset = onRemoveAsset
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                imageSection(geometry: geometry)
                
                infoSection
                    .frame(height: geometry.size.height * 0.5)
            }
        }
        .background(Color.black)
        .onTapGesture {
            focusedField = nil
            viewModel.saveCurrentAssetInfo()
        }
        .onChange(of: viewModel.assets) { newAssets in
            if newAssets.isEmpty {
                onDismiss?()
            }
        }
    }
    
    @ViewBuilder
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            TabView(selection: $viewModel.selectedIndex) {
                ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                    assetImageView(asset: asset)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.selectedIndex) { newIndex in
                viewModel.onPageChange(to: newIndex)
            }
            
            imageOverlay
        }
        .frame(height: geometry.size.height * 0.5)
    }
    
    private var imageOverlay: some View {
        VStack {
            HStack {
                Text(viewModel.counterText)
                    .font(.montserrat(.semibold, for: .caption2))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                
                Spacer()
                
                FlagView(
                    isSelected: $viewModel.isFlagged,
                    unselectedColor: .white,
                    size: 20
                ) {
                    viewModel.toggleFlagged()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Spacer()
            
            HStack {
                Button(action: {
                    viewModel.goBackward()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .opacity(viewModel.canGoBackward ? 1 : 0)
                .disabled(!viewModel.canGoBackward)
                .padding(.leading, 12)
                
                Spacer()
                
                Button(action: {
                    viewModel.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .opacity(viewModel.canGoForward ? 1 : 0)
                .disabled(!viewModel.canGoForward)
                .padding(.trailing, 12)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func assetImageView(asset: Asset) -> some View {
        ZStack {
            if asset.hasThumbnail() {
                AsyncThumbnailView(asset: asset)
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
        VStack {
            Image(asset.getFileType().placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    
    private var infoSection: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    InfoBoxView(
                        iconName: "ic_location",
                        placeholder: NSLocalizedString("Add a location (optional)", comment: ""),
                        text: $viewModel.location,
                        isMultiline: false,
                        onTextChanged: { newValue in
                            viewModel.updateLocation(newValue)
                        }
                    )
                    .focused($focusedField, equals: .location)
                    
                    InfoBoxView(
                        iconName: "ic_edit",
                        placeholder: NSLocalizedString("Add notes (optional)", comment: ""),
                        text: $viewModel.notes,
                        isMultiline: true,
                        onTextChanged: { newValue in
                            viewModel.updateNotes(newValue)
                        }
                    )
                    .focused($focusedField, equals: .notes)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .modifier(ScrollDismissesKeyboardModifier())
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct AsyncThumbnailView: View {
    let asset: Asset
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        asset.getThumbnailAsync { loadedThumbnail in
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
            }
        }
    }
}

struct ScrollDismissesKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#if DEBUG
struct DarkroomView_Previews: PreviewProvider {
    static var previews: some View {
        DarkroomView()
    }
}
#endif

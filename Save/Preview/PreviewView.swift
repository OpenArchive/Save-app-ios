//
//  PreviewView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct PreviewView: View {
    @StateObject private var viewModel = PreviewViewModel()
    
    var onNavigateToDarkroom: ((Int) -> Void)?
    var onNavigateToBatchEdit: (([Asset]) -> Void)?
    var onAddAssets: (() -> Void)?
    var onUploadComplete: (() -> Void)?
    
    private let spacing: CGFloat = 4
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing)
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.assets.isEmpty {
                emptyStateView
            } else {
                gridView
            }
            
            toolbarView
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(NSLocalizedString("No media to preview", comment: ""))
                .font(.montserrat(.medium, for: .headline))
                .foregroundColor(.gray70)
            Spacer()
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                    PreviewCellView(
                        asset: asset,
                        isSelected: viewModel.isSelected(asset),
                        refreshId: viewModel.refreshId,
                        onTap: {
                            handleTap(asset: asset, index: index)
                        },
                        onLongPress: {
                            handleLongPress(asset: asset)
                        }
                    )
                }
            }
            .padding(.horizontal, spacing)
            .padding(.top, spacing)
        }
    }
    
    private var toolbarView: some View {
        HStack(spacing: 20) {
            if viewModel.isSelectionMode {
                selectionToolbar
            } else {
                addButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    private var selectionToolbar: some View {
        HStack {
            Button(action: {
                editSelectedAssets()
            }) {
                Image("ic_batchedit")
                    .foregroundColor(.accent)
                    .font(.system(size: 24))
            }
            
            Spacer()
            
            Button(action: {
                viewModel.toggleSelectAll()
            }) {
                Text(viewModel.allSelected
                     ? NSLocalizedString("Deselect All", comment: "")
                     : NSLocalizedString("Select All", comment: ""))
                    .font(.montserrat(.semibold, for: .callout))
                    .foregroundColor(.accent)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.removeSelectedAssets()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.accent)
                    .font(.system(size: 24))
            }
        }
    }
    
    private var addButton: some View {
        Button(action: {
            onAddAssets?()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text(NSLocalizedString("Add More", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accent)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 75)
    }
    
    private func handleTap(asset: Asset, index: Int) {
        if viewModel.isSelectionMode {
            viewModel.toggleSelection(for: asset)
        } else {
            onNavigateToDarkroom?(index)
        }
    }
    
    private func handleLongPress(asset: Asset) {
        if !viewModel.isSelectionMode {
            viewModel.selectAsset(asset)
        }
    }
    
    private func editSelectedAssets() {
        let selectedAssets = viewModel.getSelectedAssets()
        
        if selectedAssets.count < 2 {
            if let firstAsset = selectedAssets.first,
               let index = viewModel.assets.firstIndex(where: { $0.id == firstAsset.id }) {
                onNavigateToDarkroom?(index)
            }
        } else {
            onNavigateToBatchEdit?(selectedAssets)
        }
    }
}

#if DEBUG
struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
    }
}
#endif

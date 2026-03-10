//
//  BrowseView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct BrowseView: View {
    @StateObject private var viewModel: BrowseViewModel
    @Environment(\.colorScheme) private var colorScheme
    var onAddFolder: (BrowseFolder) -> Void
    var onSelectionChange: (BrowseFolder?) -> Void

    init(useTorSession: Bool = false, onAddFolder: @escaping (BrowseFolder) -> Void, onSelectionChange: @escaping (BrowseFolder?) -> Void) {
        _viewModel = StateObject(wrappedValue: BrowseViewModel(useTorSession: useTorSession))
        self.onAddFolder = onAddFolder
        self.onSelectionChange = onSelectionChange
    }

    var body: some View {
        VStack(spacing: 0) {
            contentView
        }
        .background(Color(UIColor.systemBackground))
        .onChange(of: viewModel.selectedFolder) { newValue in
            onSelectionChange(newValue)
        }
        .onAppear {
            viewModel.loadFolders()
            onSelectionChange(viewModel.selectedFolder)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if !viewModel.sections.isEmpty {
            listView
        } else if !viewModel.isLoading {
            emptyStateView
        } else {
            Color(UIColor.systemBackground)
                .overlay(loadingOverlay)
        }
    }
    
    private var listView: some View {
        List {
            ForEach(viewModel.sections) { section in
                sectionView(for: section, isFirstInList: section.id == viewModel.sections.first?.id)
            }
        }
        .listStyle(.plain)
        .padding(.top, 16)
        .overlay(loadingOverlay)
    }
    
    @ViewBuilder
    private func sectionView(for section: BrowseSection, isFirstInList: Bool) -> some View {
        let sectionHeader = section.header.isEmpty ? nil : Text(section.header)
        Section(header: sectionHeader) {
            ForEach(section.items) { item in
                let isFirstRow = isFirstInList && item.id == section.items.first?.id
                rowView(for: item, isFirstRow: isFirstRow)
            }
        }
    }
    
    @ViewBuilder
    private func rowView(for item: BrowseItem, isFirstRow: Bool) -> some View {
        switch item {
        case .folder(let folder):
            folderRowView(folder: folder, isFirstRow: isFirstRow)
        case .error:
            Text(NSLocalizedString("Error loading folders", comment: ""))
                .foregroundColor(.red)
        }
    }
    
    private func folderRowView(folder: BrowseFolder, isFirstRow: Bool) -> some View {
        let isSelected = viewModel.selectedFolder?.id == folder.id
        
        return BrowseFolderRow(
            folder: folder,
            isSelected: isSelected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedFolder = folder
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(rowBackground(isSelected: isSelected))
        .listRowSeparator(isFirstRow ? .hidden : .visible, edges: .top)
        .modifier(FullWidthSeparatorModifier())
    }
    
    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accent)
                .padding(2)
        } else {
            Color.clear
        }
    }
    
    private var emptyStateView: some View {
        Text(viewModel.emptyMessage)
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(loadingOverlay)
    }
    
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                (colorScheme == .dark ? Color.black : Color.white)
                    .overlay(ProgressView())
            }
        }
        .allowsHitTesting(viewModel.isLoading)
    }
    
}

/// Makes list row separators span full width. On iOS 16+ the default insets separators
/// to content; this restores full-width. On iOS 15 separators are full-width by default.
private struct FullWidthSeparatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                .alignmentGuide(.listRowSeparatorTrailing) { d in d.width }
        } else {
            content
        }
    }
}

struct BrowseFolderRow: View {
    let folder: BrowseFolder
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var selectedForegroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        HStack(spacing: 12) {
            Image("folder_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(isSelected ? selectedForegroundColor : (colorScheme == .dark ? .white : Color(UIColor.label)))

            Text(folder.name)
                .font(.montserrat(.semibold, for: .headline))
                .foregroundColor(isSelected ? selectedForegroundColor : Color(UIColor.label))

            Spacer(minLength: 0)

            if isSelected {
                Image("check")
                    .renderingMode(.template)
                    .foregroundColor(selectedForegroundColor)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

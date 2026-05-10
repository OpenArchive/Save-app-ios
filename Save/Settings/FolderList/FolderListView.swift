//
//  FolderListView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct FolderListView: View {
    @StateObject private var viewModel: FolderListViewModel
    var onSelectProject: (Project) -> Void
    
    init(archived: Bool, onSelectProject: @escaping (Project) -> Void) {
        _viewModel = StateObject(wrappedValue: FolderListViewModel(archived: archived))
        self.onSelectProject = onSelectProject
    }
    
    var body: some View {
        Group {
            if viewModel.projects.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.projects, id: \.id) { project in
                            FolderListRow(folderName: project.name ?? "")
                                .onTapGesture {
                                    onSelectProject(project)
                                }
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .trackScreen("ArchivedFolders")
    }
    
    private var emptyView: some View {
        Text(NSLocalizedString("No archived folders found.", comment: ""))
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(Color(UIColor.gray70))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FolderListRow: View {
    let folderName: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image("folder_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(Color(UIColor.label))
            
            Text(folderName)
                .font(.montserrat(.semibold, for: .headline))
                .foregroundColor(Color(UIColor.label))
            
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}

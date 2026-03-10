//
//  ServerListView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    var onAddServer: () -> Void
    var onSelectSpace: (Space) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.spaces, id: \.id) { space in
                            ServerListRow(space: space)
                                .onTapGesture {
                                    onSelectSpace(space)
                                }
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
            }
            
            addServerButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            viewModel.refresh()
        }
        .trackScreen("ServerList")
    }
    
    private var emptyView: some View {
        Text(NSLocalizedString("No servers added yet.", comment: ""))
            .font(.montserrat(.semibold, for: .headline))
            .foregroundColor(.gray70)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 200)
    }
    
    private var addServerButton: some View {
        Button(action: onAddServer) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                Text(NSLocalizedString("Add Server", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accent)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 75)
        .padding(.bottom, 16)
    }
}

struct ServerListRow: View {
    let space: Space
    
    private var serverName: String {
        if let name = space.name, !name.isEmpty {
            return name
        }
        return space.prettyName
    }
    
    private var serverSubtitle: String {
        if space is IaSpace {
            return NSLocalizedString("Internet Archive", comment: "")
        } else if space is WebDavSpace {
            return NSLocalizedString("Private Server", comment: "")
        } else {
            return NSLocalizedString("Unknown Server", comment: "")
        }
    }
    
    private var iconName: String {
        if space is IaSpace {
            return "internet_archive"
        }
        return "private_server"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(serverName)
                    .font(.montserrat(.semibold, for: .headline))
                    .foregroundColor(Color(UIColor.label))
                
                Text(serverSubtitle)
                    .font(.montserrat(.regular, for: .subheadline))
                    .foregroundColor(Color(UIColor.subtitleText))
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

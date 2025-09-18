//
//  SpaceListView 2.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct SpaceListView: View {
    @ObservedObject var spaceState: SpaceState
    var onSelect: (StorachaSpace) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            if spaceState.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading spaces...")
                        .font(.montserrat(.medium, for: .callout))
                        .foregroundColor(.gray)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if spaceState.spaces.isEmpty {
                VStack {
                    Text("No spaces available")
                        .font(.montserrat(.medium, for: .body))
                        .foregroundColor(.gray)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(spaceState.spaces) { space in
                            Button(action: {
                                onSelect(space)
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.accentColor)
                                        .padding(.trailing, 8)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(space.name)
                                            .font(.montserrat(.semibold, for: .callout))
                                            .foregroundColor(.primary)
                                        
                                        Text(space.id)
                                            .font(.montserrat(.medium, for: .caption))
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(.label))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .onAppear {
            Task {
                await spaceState.loadSpaces()
            }
        }
    }
}

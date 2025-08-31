//
//  SpaceListView 2.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

import SwiftUI

@available(iOS 14.0, *)
struct SpaceListView: View {
    @ObservedObject var spaceState: SpaceState
    var onSelect: (StorachaSpace) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if spaceState.isLoading {
                    ProgressView("Loading spaces...")
                        .font(.montserrat(.medium, for: .caption))
                        .padding(.top, 40)
                } else if spaceState.spaces.isEmpty {
                    Text("No spaces available")
                        .font(.montserrat(.medium, for: .body))
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                } else {
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
                                        .font(.montserrat(.semibold, for: .headline))
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
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
        .onAppear {
            Task {
                await spaceState.loadSpaces()
            }
        }
    }
}

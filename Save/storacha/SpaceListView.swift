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
                    Text(NSLocalizedString("Loading spaces...", comment: ""))
                        .font(.montserrat(.medium, for: .callout))
                        .foregroundColor(.gray)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if spaceState.spaces.isEmpty {
                VStack {
                    Text(NSLocalizedString("No Spaces Available",comment: ""))
                        .font(.montserrat(.medium, for: .body))
                        .foregroundColor(.gray)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(spaceState.spaces) { space in
                            Button(action: {
                                onSelect(space)
                            }) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image("folder")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(space.name)
                                            .font(.montserrat(.semibold, for: .callout))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
//                                        Text(space.id)
//                                            .font(.montserrat(.medium, for: .caption))
//                                            .foregroundColor(.gray)
//                                            .multilineTextAlignment(.leading)
//                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(.label))
                                        .frame(width: 20)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                .refreshable {
                    await spaceState.loadSpaces()
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

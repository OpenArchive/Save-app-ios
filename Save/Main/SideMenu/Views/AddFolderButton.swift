//
//  AddFolderButton.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct AddFolderButton: View {
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        Button(action: {
            coordinator.addFolder()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))

                Text(NSLocalizedString("New Folder", comment: ""))
                    .font(.montserrat(.semibold, for: .headline))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.accent))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

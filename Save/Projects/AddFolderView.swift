//
//  AddFolderView.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct AddFolderView: View {
    var onCreateNew: () -> Void
    var onBrowse: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            
            Text(NSLocalizedString("Choose a new or existing folder to save your media in.", comment: ""))
                .font(.montserrat(.semibold, for: .headline))
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 30)
                .padding(.vertical,50)

            VStack(spacing: 24) {
                BigButtonView(
                    icon: "add_new_folder",
                    title: NSLocalizedString("Create a New Folder", comment: ""),
                    action: onCreateNew
                )
                BigButtonView(
                    icon: "browse_folder",
                    title: NSLocalizedString("Browse Existing Folders", comment: ""),
                    action: onBrowse
                )
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

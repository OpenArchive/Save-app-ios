//
//  ProjectItemView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ProjectItemView: View {
    let project: Project
    let isSelected: Bool
    let isIndented: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(isSelected ? "folder_fil" : "folder")
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(isSelected ? Color(UIColor.accent) : Color(UIColor.label))

            Text(project.name ?? "")
                .font(.montserrat(.semibold, for: .callout))
                .foregroundColor(isSelected ? Color(UIColor.label) : Color(UIColor.gray70))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.leading, isIndented ? 32 : 12)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

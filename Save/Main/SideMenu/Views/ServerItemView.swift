//
//  ServerItemView.swift
//  Save
//
//  Created by Navoda on 2026-02-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import SwiftUI

struct ServerItemView: View {
    let space: Space
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(space is IaSpace ? "internet_archive" : "private_server")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(Color(UIColor.label))

            Text(space.prettyName)
                .font(.montserrat(.medium, for: .subheadline))
                .foregroundColor(Color(UIColor.label))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isSelected ? Color(UIColor.accent) : Color(UIColor.pillBackground))
        .contentShape(Rectangle())
    }
}

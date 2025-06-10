//
//  ToggleSwitch.swift
//  Save
//
//  Created by navoda on 2025-06-10.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

// MARK: - ToggleSwitch
struct ToggleSwitch: View {
    var title: String
    var subtitle: String?
    var isDisabled:Bool = false
    @Binding var isOn: Bool
    var action: ((Bool) -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading,spacing: 1) {
                Text(title)
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    if #available(iOS 14.0, *) {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption2))
                            .foregroundColor(.settingSubtitle)
                    } else {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption))
                            .foregroundColor(.settingSubtitle)
                    }
                    
                }
            }.padding(.vertical, 6)
            Spacer()
            if #available(iOS 15.0, *) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .disabled(isDisabled)
                    .tint(.accent)
                    .onChange(of: isOn) { value in
                        action?(value)
                    }
            } else if #available(iOS 14.0, *) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .disabled(isDisabled)
                    .accentColor(isOn ? .accentColor : .gray30)
                    .onChange(of: isOn) { value in
                        action?(value)
                    }
            } else {
                
            }
        }
    }
}

// MARK: - SubItem
struct SubItem: View {
    var title: String
    var subtitle: String?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading,spacing: 1) {
                Text(title)
                    .font(.montserrat(.medium, for: .subheadline))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    if #available(iOS 14.0, *) {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption2))
                            .foregroundColor(.settingSubtitle)
                    } else {
                        Text(subtitle)
                            .font(.montserrat(.mediumItalic, for: .caption))
                            .foregroundColor(.settingSubtitle)
                    }
                }
            }
            .padding(.vertical, 6)
        }.buttonStyle(PlainButtonStyle())
    }
}

// MARK: - HideItemSeparator
struct HideItemSeparator: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content.listRowSeparator(.hidden) // Works in iOS 15+
        } else {
            content.listRowBackground(Color.clear) // Hides background in iOS 14
        }
    }
}

// MARK: - ListSpacingModifier
struct ListSpacingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.listSectionSpacing(1) // iOS 17+ uses listSectionSpacing
        } else {
            content
                .environment(\.defaultMinListHeaderHeight, 0) // iOS 16 and below
                .introspect(.list, on: .iOS(.v15)) { tableView in
                    tableView.sectionHeaderHeight = 0
                    tableView.sectionFooterHeight = 0
                }
        }
    }
}

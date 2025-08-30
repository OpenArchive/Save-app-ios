//
//  ViewExtensions.swift
//  Save
//
//  Created by navoda on 2025-08-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//
import SwiftUI

extension View {
    func toggleTint(_ color: Color) -> some View {
        self.modifier(ToggleTintModifier(color: color))
    }
}

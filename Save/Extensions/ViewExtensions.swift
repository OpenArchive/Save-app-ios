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
        /// Backward-compatible `.task {}` for iOS 14+
        @ViewBuilder
        func compatTask(_ action: @escaping () async -> Void) -> some View {
            if #available(iOS 15.0, *) {
                self.task {
                    await action()
                }
            } else {
                self.onAppear {
                    Task {
                        await action()
                    }
                }
            }
        }

        /// Backward-compatible `.ignoresSafeArea()` for iOS 14+
        func compatIgnoresSafeArea() -> some View {
            if #available(iOS 14.0, *) {
                return AnyView(self.ignoresSafeArea())
            } else {
                return AnyView(self.edgesIgnoringSafeArea(.all))
            }
        }

}

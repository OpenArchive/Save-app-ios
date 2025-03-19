//
//  NumericKeypad.swift
//  Save
//
//  Created by Elelan on 2024/12/5.
//  Copyright © 2024 Open Archive. All rights reserved.
//


import SwiftUI

// Number pad spacing
private let keypadRowSpacing: CGFloat = 24
private let keypadColumnSpacing: CGFloat = 24
private let keypadButtonSize: CGFloat = 72

struct NumericKeypad: View {
    var isEnabled: Bool
    var onNumberClick: (String) -> Void
    var onDelete: () -> Void
    var onEnter: () -> Void

    private let gridKeys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "delete", "0", "enter"]

    var body: some View {
        VStack(spacing: keypadColumnSpacing) {
            ForEach(0..<4) { rowIndex in
                HStack(spacing: keypadRowSpacing) {
                    ForEach(0..<3) { columnIndex in
                        let index = rowIndex * 3 + columnIndex
                        let key = gridKeys[index]

                        if key == "delete" {
                            SpecialButton(iconName: "delete.left.fill", backgroundColor: Color.red.opacity(0.3)) {
                                if isEnabled {
                                    generateHapticFeedback()
                                    onDelete()
                                }
                            }
                        } else if key == "enter" {
                            SpecialButton(iconName: "arrow.right", backgroundColor: Color.accentColor.opacity(0.8)) {
                                if isEnabled {
                                    generateHapticFeedback()
                                    onEnter()
                                }
                            }
                        } else {
                            NumberButton(number: key) {
                                if isEnabled {
                                    generateHapticFeedback()
                                    onNumberClick(key)
                                }
                            }
                            .disabled(!isEnabled)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Generates a light haptic feedback when a number is tapped.
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private struct NumberButton: View {
    var number: String
    var action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var isTapped: Bool = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.05)) {
                isTapped = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.05)) {
                    isTapped = false
                }
            }
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(isTapped ? Color.accentColor.opacity(0.5) : Color.accentColor, lineWidth: isTapped ? 4 : 2)
                    .scaleEffect(isTapped ? 0.95 : 1.0)

                Text(number)
                    .font(.title)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
            }
            .frame(width: keypadButtonSize, height: keypadButtonSize)
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

private struct SpecialButton: View {
    var iconName: String
    var backgroundColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: keypadButtonSize, height: keypadButtonSize)

                Image(systemName: iconName)
                    .font(.title)
                    .foregroundColor(.primary)
            }
        }
    }
}

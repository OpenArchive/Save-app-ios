//
//  NumericKeypad.swift
//  Save
//
//  Created by Elelan on 2024/12/5.
//  Copyright © 2024 Open Archive. All rights reserved.
//


import SwiftUI

// number pad spacing
private let keypadRowSpacing: CGFloat = 24
private let keypadColumnSpacing: CGFloat = 24
private let keypadButtonSize: CGFloat = 72

struct NumericKeypad: View {
    var isEnabled: Bool
    var onNumberClick: (String) -> Void
    
    private let keys = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", " "]
    ]
    
    private let gridKeys: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", " "]
    
    var body: some View {
        
        
        VStack(spacing: keypadColumnSpacing) {
            
            ForEach(0..<4) { rowIndex in
                HStack(spacing: keypadRowSpacing) {
                    ForEach(0..<3) { columnIndex in
                        let index = rowIndex * 3 + columnIndex
                        let key = gridKeys[index]
                        
                        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Spacer()
                                .frame(width: keypadButtonSize, height: keypadButtonSize)
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
            
//            ForEach(keys, id: \.self) { row in
//                
//                HStack(spacing: keypadSpacing) {
//                    
//                    ForEach(row, id: \.self) { key in
//                        
//                        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
//                            
//                            Spacer()
//                            //.frame(width: keypadButtonSize, height: keypadButtonSize)
//                            
//                        } else {
//                            
//                            NumberButton(number: key) {
//                                if isEnabled {
//                                    generateHapticFeedback()
//                                    onNumberClick(key)
//                                }
//                            }.disabled(!isEnabled)
//                        }
//                    }
//                }
//            }
        }.frame(maxWidth: .infinity)
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
    @State private var isTapped: Bool = false // Track tap state
    
    var body: some View {
        Button(action: {
            // Perform visual feedback
            withAnimation(.easeOut(duration: 0.05)) {
                isTapped = true
            }
            
            // Reset visual feedback after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeIn(duration: 0.05)) {
                    isTapped = false
                }
            }
            
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(isTapped ? Color.accent.opacity(0.5) : Color.accent, lineWidth: isTapped ? 4 : 2)
                    .scaleEffect(isTapped ? 0.95 : 1.0) // Shrink slightly on tap
                //.frame(width: keypadButtonSize, height: keypadButtonSize)
                
                Text("\(number)")
                    .font(.title)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                
            }
            //.frame(maxWidth: .infinity)
            .frame(width: keypadButtonSize, height: keypadButtonSize)
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

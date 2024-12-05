//
//  PasscodeDots.swift
//  Save
//
//  Created by Elelan on 2024/12/5.
//  Copyright © 2024 Open Archive. All rights reserved.
//


import SwiftUI

struct PasscodeDots: View {
    
    let passcodeLength: Int
    let currentPasscodeLength: Int
    let shouldShake: Bool
    
    let onAnimationCompleted: () -> Void
    
    @State private var shakeOffset: CGFloat = 0
    @State private var animatableShakeValue: CGFloat = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        if #available(iOS 14.0, *) {
            HStack(spacing: 12) {
                ForEach(0..<passcodeLength, id: \.self) { index in
                    Circle()
                        .fill(index < currentPasscodeLength
                              ? (colorScheme == .dark ? Color.white : Color.black)
                              : Color.gray.opacity(0.5)
                        )
                        .frame(width: 20, height: 20)
                }
            }
            .offset(x: shakeOffset)
            //.modifier(ShakeEffect(shakes: 3, amplitude: 20, animatableData: animatableShakeValue))
            .onChange(of: shouldShake) { newValue in
                if newValue {
                    shakeAnimation()
                    //startShakeAnimation()
                }
            }
        } else {
            // Fallback on earlier versions
            Text("")
        }
    }
    private func shakeAnimation() {
        let offsets: [CGFloat] = [30, 20, 10]
        var delay: Double = 0
        
        for offset in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    shakeOffset = -offset
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    shakeOffset = offset
                }
            }
            
            delay += 0.2 // Increase the delay for the next shake
        }
        
        // Reset to the original position after the final shake
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onAnimationCompleted() // Notify that animation has completed
            }
        }
    }
    
    
    private func startShakeAnimation() {
        
        // Total duration for the full shake animation
        let totalDuration: Double = 1.2
        let individualDuration: Double = totalDuration / 3 // Divide among the 3 shakes
        
        // Amplitudes for each shake cycle
        let amplitudes: [CGFloat] = [20, 10, 5]
        
        for (index, amplitude) in amplitudes.enumerated() {
            let startDelay = individualDuration * Double(index) // Delays each cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
                    animatableShakeValue = amplitude / 20 // Normalize amplitude
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + individualDuration / 2) {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 8)) {
                    animatableShakeValue = 0 // Reset back to neutral for each shake
                }
            }
        }
        
        //        withAnimation(.easeInOut(duration: 0.3)) {
        //            animatableShakeValue = 1
        //        }
        //
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        //            withAnimation(.easeInOut(duration: 0.3)) {
        //                animatableShakeValue = 0
        //            }
        //        }
    }
}

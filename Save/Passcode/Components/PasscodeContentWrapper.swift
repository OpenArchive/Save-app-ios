//
//  PasscodeContentWrapper.swift
//  Save
//
//  Created by Elelan on 2024/12/5.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

struct PasscodeContentWrapper: View {
    
    
    let title: String
    let subtitle:String
    let passcode: String
    let passcodeLength: Int
    let shouldShake: Bool
    let isEnabled: Bool
    let isPasscodeEntry:Bool
    let showPasswordMismatch: Bool
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    let onEnterClick: () -> Void
    let onExit: () -> Void
    let onAnimationCompleted: () -> Void
    
    @State private var showToast = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            if(isPasscodeEntry){
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)}
            Text(title)
                .font(.montserrat(.semibold, for: .headline))
                .padding(.top,30)
            if(!subtitle.isEmpty){
                    Text(subtitle)
                    .font(.montserrat(.medium, for: .callout))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.redButton)
                        .padding(.top, 18)
                        .padding(.horizontal,26)
               
            }
            // MARK: Passcode Dots
            PasscodeDots(
                passcodeLength: passcodeLength,
                currentPasscodeLength: passcode.count,
                shouldShake: shouldShake,
                onAnimationCompleted: onAnimationCompleted
            )
            .padding(.vertical, 50)

            // MARK: Numeric Keypad
            NumericKeypad(
                isEnabled: isEnabled,
                onNumberClick: onNumberClick,
                onDelete: onBackspaceClick,
                onEnter: onEnterClick
            )
            .padding(.horizontal, 15)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 40)
        .edgesIgnoringSafeArea(.bottom)
        .toast(isShowing: $showToast, message: NSLocalizedString("Passcodes do not match. Try again.", comment: ""))
                .onChange(of: showPasswordMismatch) { shouldShow in
                    if shouldShow && !isPasscodeEntry {
                        withAnimation {
                            showToast = true
                        }
                    }
                }
    }

}

struct PasscodeContentWrapper_Previews: PreviewProvider {
    
    
    static var previews: some View {
        
        PasscodeContentWrapper(
            title: "Title",
            subtitle: "SubTitle",
            passcode: "123",
            passcodeLength: 6,
            shouldShake: false,
            isEnabled: true, isPasscodeEntry: false, showPasswordMismatch: false,
            onNumberClick: { _ in },
            onBackspaceClick: { }, onEnterClick: {},
            onExit: { },
            onAnimationCompleted: {}
        )
    }
}
// Toast View
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.montserrat(.medium, for: .subheadline))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal, 20)
    }
}

// Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                        .padding(.bottom, 50)
                }
                .animation(.spring(), value: isShowing)
            }
        }
    }
}

// Extension for easy usage
extension View {
    func toast(isShowing: Binding<Bool>, message: String, duration: TimeInterval = 2.0) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, duration: duration))
    }
}

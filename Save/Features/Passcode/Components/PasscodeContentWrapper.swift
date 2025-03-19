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
    
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    let onEnterClick: () -> Void
    let onExit: () -> Void
    
    let onAnimationCompleted: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.headlineFont2)
                .padding(.top,30)
            if(!subtitle.isEmpty){
                Text(subtitle)
                    .font(.errorText)
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
            isEnabled: true,
            onNumberClick: { _ in },
            onBackspaceClick: { }, onEnterClick: {},
            onExit: { },
            onAnimationCompleted: {}
        )
    }
}

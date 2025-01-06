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
    let passcode: String
    let passcodeLength: Int
    let shouldShake: Bool
    let isEnabled: Bool
    
    let onNumberClick: (String) -> Void
    let onBackspaceClick: () -> Void
    let onExit: () -> Void
    
    let onAnimationCompleted: () -> Void
    
    var body: some View {
        
        VStack(spacing: 16) {
            
            // MARK: Logo Section
            Image("save-open-archive-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer(minLength: 30)
            
            // MARK: Title Section
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .padding(.vertical, 8)
            
            // MARK: Passcode Dots
            PasscodeDots(
                passcodeLength: passcodeLength,
                currentPasscodeLength: passcode.count,
                shouldShake: shouldShake,
                onAnimationCompleted: onAnimationCompleted
            )
            .padding(.bottom, 20)
            
            //Spacer()
            
            // MARK: Numeric Keypad
            NumericKeypad(
                isEnabled: isEnabled,
                onNumberClick: onNumberClick
            )
            //.frame(width: .infinity, height: .infinity )
            .padding(.horizontal, 15)
            
            Spacer()
            
            // MARK: Bottom Buttons
            HStack(spacing: 16) {
                
                Button(action: onExit) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                
                Button(action: onBackspaceClick) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(passcode.count == 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.bottom)
        
    }
}

struct PasscodeContentWrapper_Previews: PreviewProvider {
    
    
    static var previews: some View {
        
        PasscodeContentWrapper(
            title: "Title",
            passcode: "123",
            passcodeLength: 6,
            shouldShake: false,
            isEnabled: true,
            onNumberClick: { _ in },
            onBackspaceClick: { },
            onExit: { },
            onAnimationCompleted: {}
        )
    }
}

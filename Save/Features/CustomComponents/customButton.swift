//
//  customButton.swift
//  Save
//
//  Created by navoda on 2025-02-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct CustomButton: View {
    var title: String
    var backgroundColor: Color = .clear
    var textColor: Color = .primary
    var borderColor: Color = .red
    var borderWidth: CGFloat = 2
    var cornerRadius: CGFloat = 8
    var fontWeight: Font.Weight = .bold
    var isOutlined: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
            
                .font(.montserrat(.semibold, for: .callout))
                .frame(maxWidth: .infinity)
                .padding()
                .background(isOutlined ? Color.clear : backgroundColor)
                .foregroundColor(isOutlined ? borderColor : textColor)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isOutlined ? borderColor : Color.clear, lineWidth: borderWidth)
                )
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
}

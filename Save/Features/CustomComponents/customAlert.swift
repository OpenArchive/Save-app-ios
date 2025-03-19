//
//  customAlert.swift
//  Save
//
//  Created by navoda on 2025-02-03.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct CustomAlertView: View {
    var title: String
    var message: String
    var primaryButtonTitle: String
    var iconImage:Image?
    var iconTint: Color? = .accent
    var primaryButtonAction: (() -> Void)
    var secondaryButtonTitle: String?
    var secondaryButtonIsOutlined : Bool = false
    var secondaryButtonAction: (() -> Void)?
    var showCheckbox: Bool = false
    var isRemoveAlert: Bool = false
    @State private var checkboxChecked: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            if let iconImage = iconImage {
                iconImage
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(iconTint)
                    .padding(.top, 5)
                    .padding(.bottom,10)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.accentColor)
                    .padding(.top, 5)
                    .padding(.bottom,10)
            }
            
            Text(title)
                .font(.headlineFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.menuMediumFont)
                .multilineTextAlignment(.center)
                .padding(.bottom,10)
                .foregroundColor(.alertSubtitle)
            
            if showCheckbox {
                Toggle(isOn: $checkboxChecked) {
                    Text(NSLocalizedString("Do not show me this again", comment: ""))
                        .font(.menuMediumFont)
                        .foregroundColor(.alertSubtitle)
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            
            VStack(spacing: 10) {
                if(isRemoveAlert){
                    CustomButton(
                        title: primaryButtonTitle,
                        backgroundColor: .clear,
                        textColor: .primary,
                        isOutlined: true, action: primaryButtonAction
                    )
                }
                else{
                    CustomButton(
                        title: primaryButtonTitle,
                        backgroundColor: .accent,
                        textColor: .black,
                        action: primaryButtonAction
                    ).padding(.top,15)
                        .padding(.bottom, secondaryButtonTitle != nil ? 0 : 15)
                }
                
                if let secondaryButtonTitle = secondaryButtonTitle {
                    CustomButton(
                        title: secondaryButtonTitle,
                        backgroundColor: .clear,
                        textColor: .primary,
                        isOutlined: secondaryButtonIsOutlined, action: secondaryButtonAction!
                    )
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.primary)
                }
                
                
                
            }
        }
        .padding()
        .background(Color.alertBg)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square").frame(width: 30, height: 30)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}
#Preview {
    
}
struct CustomAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview for a warning alert
            CustomAlertView(
                title: "Warning",
                message: "Once uploaded, you will not be able to edit media.",
                primaryButtonTitle: "OK",
                primaryButtonAction: {},
                secondaryButtonTitle: "Cancel",
                secondaryButtonAction: {},
                showCheckbox: true
            )
            // Preview for a success alert
            CustomAlertView(
                title: "Success",
                message: "You are now connected to your server.",
                primaryButtonTitle: "OK",
                primaryButtonAction: {},
                secondaryButtonTitle: nil,
                secondaryButtonAction: nil,
                showCheckbox: false
            )
        }
    }
}

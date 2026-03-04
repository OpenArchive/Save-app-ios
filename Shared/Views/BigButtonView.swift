//
//  BigButtonView.swift
//  Save
//
//  SwiftUI equivalent of BigButton UIView
//

import SwiftUI

struct BigButtonView: View {

    var icon: String?
    var title: String
    var subtitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 15) {
                if let icon = icon {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(Color(UIColor.accent))
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(Color(UIColor.label))

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.montserrat(.regular, for: .subheadline))
                            .foregroundColor(.gray70)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image("forward_arrow")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color(UIColor.label))
                    .frame(width: 24, height: 24)
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("border-bg"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

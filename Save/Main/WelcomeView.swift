//  WelcomeView.swift
//  Save

import SwiftUI

struct WelcomeView: View {
    let hintText: String
    let showWelcomeTitle: Bool
    @State private var textGroupHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let textCenterY = geometry.size.height / 2 - 61.5
            let arrowTop = textCenterY + textGroupHeight / 2
            let arrowMaxHeight = geometry.size.height - 8 - arrowTop

            ZStack(alignment: .topLeading) {

                VStack(spacing: 8) {
                    if showWelcomeTitle {
                        Text(NSLocalizedString("Welcome!", comment: ""))
                            .font(.montserrat(.bold, for: .largeTitle))
                            .foregroundColor(Color(.welcome))
                    }

                    Text(hintText)
                        .font(Font(UIFont(name: "Montserrat-Bold", size: 24)!))
                        .foregroundColor(Color(.mediaSubtitle))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { textGroupHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { textGroupHeight = $0 }
                    }
                )
                .position(x: centerX, y: textCenterY)

                Image("welcome_arrow")
                    .renderingMode(.template)
                    .foregroundColor(Color("welcome-arrow"))
                    .scaledToFit()
                    .frame(maxHeight: max(0, arrowMaxHeight))
                    .offset(x: centerX + 30, y: arrowTop)
            }
        }
    }
}

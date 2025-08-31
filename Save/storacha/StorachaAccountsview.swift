//
//  StorachaAccountsviewController.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

struct AccountListView: View {
    @EnvironmentObject  var accountState: StorachaAppState
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 40)

                if accountState.accounts.isEmpty {
                    Text("No accounts found")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(accountState.accounts, id: \.self) { email in
                        Button(action: { onSelect(email) }) {
                            HStack {
                                Text(email)
                                    .foregroundColor(Color(.label)).font(.montserrat(.semibold, for: .headline))
                                Spacer()
                                Image(uiImage: (UIImage(named: "forward_arrow")?.withRenderingMode(.alwaysTemplate))!)
                                    .foregroundColor(Color(.label))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.gray30, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        } .onAppear {
            accountState.loadAccounts()
        }
    }
}

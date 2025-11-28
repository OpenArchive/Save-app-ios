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
              
                if accountState.accounts.isEmpty {
                    Spacer()
                    Text(NSLocalizedString("No Accounts Available", comment: ""))
                        .foregroundColor(.gray70)
                        .padding()
                    Spacer()
                } else {
                    ForEach(accountState.accounts, id: \.self) { email in
                        Button(action: { onSelect(email) }) {
                            HStack {
                                Image("user_icon")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.trailing, 8)
                                    .foregroundColor(.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(email)
                                        .font(.montserrat(.semibold, for: .callout))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color(.label))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                           
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

//
//  DIDAccessViewController.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
class DIDAccessViewController: UIViewController {
    private let viewModel: DIDAccessViewModel

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, spaceId: String, did: String) {
        self.viewModel = DIDAccessViewModel(store: store, spaceId: spaceId, did: did)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let contentView = DIDAccessView(viewModel: viewModel)
        let hosting = UIHostingController(rootView: contentView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }
}
struct DIDAccessView: View {
    @ObservedObject var viewModel: DIDAccessViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        if #available(iOS 14.0, *) {
            VStack(spacing: 20) {
                Spacer().frame(height: 30)
                
                Text(viewModel.did)
                    .font(.montserrat(.semibold, for: .headline))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.middle)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 24) {
                    Toggle("Users can read the content within the space", isOn: $viewModel.canRead)
                    Toggle("Users can write content to the space", isOn: $viewModel.canWrite)
                    Toggle("Users can delete the content within the space", isOn: $viewModel.canDelete)
                }
                .font(.montserrat(.medium, for: .callout))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    viewModel.revokeAccess()
                }) {
                    Text("Revoke Access")
                        .font(.montserrat(.semibold, for: .headline))
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .onAppear {
                viewModel.loadAccess()
            }
            .onChange(of: viewModel.didRevoked) { revoked in
                if revoked {
                    presentationMode.wrappedValue.dismiss() // ✅ Navigate back
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
class DIDAccessViewModel: ObservableObject {
    @Published var canRead = true
    @Published var canWrite = false
    @Published var canDelete = false
    @Published var didRevoked = false

    let did: String
    let spaceId: String
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, spaceId: String, did: String) {
        self.store = store
        self.spaceId = spaceId
        self.did = did
    }

    func loadAccess() {
        // Load access details if needed
    }

    func revokeAccess() {
        store.dispatch(.revokeAccess(spaceId: spaceId, did: did))
        didRevoked = true 
    }
}

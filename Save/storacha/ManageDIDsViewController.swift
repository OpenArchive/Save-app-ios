//
//  ManageDIDsViewController.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class ManageDIDsViewController: UIViewController {
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private let space: StorachaSpace
    private var viewModel: ManageDIDsViewModel!

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, space: StorachaSpace) {
        self.store = store
        self.space = space
        super.init(nibName: nil, bundle: nil)
        self.viewModel = ManageDIDsViewModel(store: store, spaceId: space.id)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Manage DIDs"
        view.backgroundColor = .systemBackground
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        let contentView = ManageDIDsView(viewModel: viewModel) { [weak self] isDisabled in
            self?.navigationItem.hidesBackButton = isDisabled
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addDidTapped))
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

    private func navigateToDIDAccess(did: String) {
      let vc = DIDAccessViewController(store: store, spaceId: space.id, did: did)
      navigationController?.pushViewController(vc, animated: true)
    }
    @objc func addDidTapped(){
        let scanVM = ScanDIDViewModel(store: store, spaceId: space.id)
            let scanView = ScanDIDView(viewModel: scanVM)
            let hosting = UIHostingController(rootView: scanView)
            hosting.title = "Scan QR"
            navigationController?.pushViewController(hosting, animated: true)
    }
}

class ManageDIDsViewModel: ObservableObject {
    @Published var dids: [String] = []

    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private let spaceId: String
    private var cancellables = Set<AnyCancellable>()

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, spaceId: String) {
        self.store = store
        self.spaceId = spaceId
        bind()
    }

    private func bind() {
        if #available(iOS 14.0, *) {
            store.$state
                .map { state in
                    state.spaces.first(where: { $0.id == self.spaceId })?.dids ?? []
                }
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .assign(to: &$dids)
        } else {
            // Fallback on earlier versions
        }
    }
    func deleteDID(_ did: String) {
        store.dispatch(.revokeAccess(spaceId: spaceId, did: did))
    }
    func loadDIDs() {
        store.dispatch(.loadSpaces)
    }
}



struct ManageDIDsView: View {
    @ObservedObject var viewModel: ManageDIDsViewModel
    let disableBackAction: (Bool) -> Void
    @State private var didToDelete: String? = nil
    @State private var showDeleteConfirmation = false
    var body: some View {
        if #available(iOS 15.0, *) {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.dids, id: \.self) { did in
                            HStack {
                                Image(systemName: "person.circle")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.accentColor)
                                    .padding(.trailing, 8)
                                Text(did)
                                    .font(.montserrat(.medium, for: .body))
                                    .foregroundColor(Color(.label))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .truncationMode(.tail)
                                Spacer()
                                Button(action: {
                                    didToDelete = did
                                    showDeleteConfirmation = true
                                    disableBackAction(true)
                                    
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.gray30, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .onAppear {
                viewModel.loadDIDs()
            }.overlay {
                if showDeleteConfirmation {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        
                        CustomAlertView(
                            title: NSLocalizedString("Revoke Access?", comment: ""),
                            message: String(format: NSLocalizedString(
                                "This will revoke access for this DID from the %@ app.",
                                comment: "Placeholder is app name"
                            ), Bundle.main.displayName),
                            primaryButtonTitle: NSLocalizedString("Revoke", comment: ""),
                            iconImage: Image("trash_icon"),
                            iconTint: .gray,
                            primaryButtonAction: {
                                showDeleteConfirmation = false
                                viewModel.deleteDID(didToDelete ?? "")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.loadDIDs()
                                    disableBackAction(false)
                                    }
                            },
                            secondaryButtonTitle: NSLocalizedString("Cancel", comment: ""),
                            secondaryButtonAction: {
                                disableBackAction(false)
                                showDeleteConfirmation = false
                            },
                            showCheckbox: false,
                            isRemoveAlert: true
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        } else {
            // Fallback on earlier versions
        }

    }
}

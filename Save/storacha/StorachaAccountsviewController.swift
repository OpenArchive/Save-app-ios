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

class StorachaAccountsviewController: UIViewController {
    private let store = AccountsStore(initial: AccountsAppState(), reducer: appReducer)
    private var cancellables = Set<AnyCancellable>()
    
    override func viewWillAppear(_ animated: Bool) {
           super.viewWillAppear(animated)
           store.dispatch(.loadAccounts)
       }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Accounts"

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addAccountTapped))
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        let viewModel = AccountListViewModel(store: store)
        let contentView = AccountListView(viewModel: viewModel)
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

        // Observe navigation
        store.$state.map(\ .navigation)
            .removeDuplicates()
            .sink { [weak self] nav in
                guard let self = self else { return }
                switch nav {
                case .showAccountDetail(let email):
                    self.navigateToDetail(email: email)
                    self.store.dispatch(.resetNavigation)
                case .showAddAccount:
                    self.showAddAccount()
                    self.store.dispatch(.resetNavigation)
                case .idle,.showAddSpace,.showSpaceDetail(_):
                    break
                            
                }
            }
            .store(in: &cancellables)
        store.dispatch(.loadAccounts)

    }

    private func navigateToDetail(email: String) {
           let detailView = AccountDetailView(email: email) { [weak self] in
               self?.store.dispatch(.removeAccount(email))
               self?.navigationController?.popViewController(animated: true)
           }
           let hosting = UIHostingController(rootView: detailView)
           hosting.title = "Account"
           navigationController?.pushViewController(hosting, animated: true)
       }
    @objc private func addAccountTapped() {
        store.dispatch(.addAccount)
    }

    private func showAddAccount() {
        let addVC = StorachaLoginViewController()
        navigationController?.pushViewController(addVC, animated: true)
    }
}

struct AccountListView: View {
    @ObservedObject var viewModel: AccountListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 40)
                ForEach(viewModel.accounts, id: \ .self) { email in
                    Button(action: {
                        viewModel.select(email: email)
                    }) {
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
            .padding(.top)
        }
    }
}

struct StorachaSpace: Codable, Equatable, Identifiable {
        let id: String
        var name: String
        var files: [String] = []
        var dids: [String]
}

struct AccountsAppState {
    var accounts: [String] = []
    var spaces: [StorachaSpace] = []
    var navigation: NavigationState = .idle
}

enum NavigationState: Equatable {
    case idle
    case showAccountDetail(String)
    case showAddAccount
    case showAddSpace
    case showSpaceDetail(StorachaSpace)
}

enum AccountsAppAction {
    // Accounts
    case loadAccounts
    case selectAccount(String)
    case addAccount
    case removeAccount(String)

    // Spaces
    case loadSpaces
    case addSpace(name: String, did: String)
    case removeSpace(String)
    case selectSpace(
        StorachaSpace)
    case addFile(toSpaceId: String, fileName: String)
    case revokeAccess(spaceId: String, did: String)
    case addDID(spaceId: String, did: String)


    // General
    case resetNavigation
}
func appReducer(state: inout AccountsAppState, action: AccountsAppAction) {
    switch action {

    // MARK: Accounts
    case .loadAccounts:
        state.navigation = .idle
        state.accounts = UserDefaults.standard.stringArray(forKey: "storedAccounts") ?? []

    case .selectAccount(let email):
        state.navigation = .showAccountDetail(email)

    case .addAccount:
        state.navigation = .showAddAccount

    case .removeAccount(let email):
        var stored = UserDefaults.standard.stringArray(forKey: "storedAccounts") ?? []
        stored.removeAll { $0 == email }
        UserDefaults.standard.setValue(stored, forKey: "storedAccounts")
        state.accounts = stored
        state.navigation = .idle

    // MARK: Spaces
    case .loadSpaces:
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           let saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {
            state.spaces = saved
        }

    case .addSpace(let name, let did):
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           let saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {
            state.spaces = saved
        }
        var spaces = state.spaces
      
           let newSpace = StorachaSpace(id: UUID().uuidString, name: name, dids: [did])
           spaces.append(newSpace)
           if let encoded = try? JSONEncoder().encode(spaces) {
               UserDefaults.standard.setValue(encoded, forKey: "storedSpaces")
           }
        state.spaces = spaces
        state.navigation = .idle

    case .removeSpace(let id):
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           let saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {
            state.spaces = saved
        }
        var spaces = state.spaces
        spaces.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.setValue(encoded, forKey: "storedSpaces")
        }
        state.spaces = spaces
        state.navigation = .idle
    case .addFile(let spaceId, let fileName):
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           let saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {
            state.spaces = saved
        }
        if let index = state.spaces.firstIndex(where: { $0.id == spaceId }) {
            var updatedSpace = state.spaces[index]
                  updatedSpace.files.append(fileName)
                  state.spaces[index] = updatedSpace 
            if let encoded = try? JSONEncoder().encode(state.spaces) {
                UserDefaults.standard.set(encoded, forKey: "storedSpaces")
            }
            state.navigation = .idle
        }
    case .selectSpace(let space):
        state.navigation = .showSpaceDetail(space)

    case .resetNavigation:
        state.navigation = .idle
    case .revokeAccess(let spaceId, let did):
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           var saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {

            if let index = saved.firstIndex(where: { $0.id == spaceId }) {
                saved[index].dids.removeAll { $0 == did }
                // optionally: remove accessControl[did] too
                if let encoded = try? JSONEncoder().encode(saved) {
                    UserDefaults.standard.set(encoded, forKey: "storedSpaces")
                }
                state.spaces = saved
            }
        }
    case .addDID(let spaceId, let did):
        if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
           var saved = try? JSONDecoder().decode([StorachaSpace].self, from: data) {

            if let index = saved.firstIndex(where: { $0.id == spaceId }) {
                var space = saved[index]
                if !space.dids.contains(did) {
                    space.dids.append(did)
                    saved[index] = space

                    if let encoded = try? JSONEncoder().encode(saved) {
                        UserDefaults.standard.set(encoded, forKey: "storedSpaces")
                    }
                    state.spaces = saved
                }
            }
        }


    }
}


class AccountsStore<State, Action>: ObservableObject {
    @Published private(set) var state: State
    private let reducer: (inout State, Action) -> Void

    init(initial: State, reducer: @escaping (inout State, Action) -> Void) {
        self.state = initial
        self.reducer = reducer
    }

    func dispatch(_ action: Action) {
        reducer(&state, action)
    }
}


// MARK: - SwiftUI View + ViewModel

class AccountListViewModel: ObservableObject {
    @Published var accounts: [String] = []

    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private var cancellables = Set<AnyCancellable>()

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>) {
        self.store = store
        if #available(iOS 14.0, *) {
            store.$state.map(\ .accounts)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .assign(to: &$accounts)
        } else {
            // Fallback on earlier versions
        }
    }

    func select(email: String) {
        store.dispatch(.selectAccount(email))
    }
}

struct AccountDetailView: View {
    var email: String
    var onLogout: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: 80)

            Text(email).font(.montserrat(.semibold, for: .subheadline))
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free Tier - ") .font(.montserrat(.semibold, for: .title)) + Text("5GB") .font(.montserrat(.bold, for: .largeTitle))
                    Text("Remaining Storage • 100%")
                        .font(.montserrat(.medium, for: .caption))
                        .foregroundColor(.gray70)
                }

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0.0, to: 1.0)
                        .stroke(Color.accentColor, lineWidth: 10)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 24)

            Spacer()

            Button(action: {
                onLogout()
            }) {
                Text("Log out")
                    .font(.montserrat(.semibold, for: .headline))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

//
//  SpaceListView.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI

struct SpaceListView: View {
    @ObservedObject var viewModel: SpaceListViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 10)

                ForEach(viewModel.spaces) { space in
                    Button(action: {
                        viewModel.select(space: space)
                    }) {
                        HStack {
                            Image(systemName: "folder")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.accentColor)
                                .padding(.trailing, 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(space.name)
                                    .font(.montserrat(.semibold, for: .headline))
                                    .foregroundColor(.primary)

                                Text(space.id)
                                    .font(.montserrat(.medium, for: .caption))
                                    .foregroundColor(.gray70)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(.label))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
    }
}
import Combine
import Foundation

class SpaceListViewModel: ObservableObject {
    @Published var spaces: [StorachaSpace] = []

    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private var cancellables = Set<AnyCancellable>()

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>) {
        self.store = store

        // Bind Redux state to published property
        if #available(iOS 14.0, *) {
            store.$state
                .map(\.spaces)
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .assign(to: &$spaces)
        } else {
            // Fallback on earlier versions
        }
    }

    func select(space: StorachaSpace) {
        store.dispatch(.selectSpace(space))
    }
}
class SpaceListViewController: UIViewController {
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private var cancellables = Set<AnyCancellable>()

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.dispatch(.loadSpaces)
        
    }
    override func viewWillDisappear(_ animated: Bool) {
      
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "My spaces"
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.hidesBackButton = true

           // Add custom back button
           navigationItem.leftBarButtonItem = UIBarButtonItem(
               image: UIImage(systemName: "chevron.left"),
               style: .plain,
               target: self,
               action: #selector(customBackTapped)
           )
       
        let viewModel = SpaceListViewModel(store: store)
        let contentView = SpaceListView(viewModel: viewModel)
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

        // Navigation listener
        store.$state.map(\.navigation)
            .removeDuplicates()
            .sink { [weak self] nav in
                guard let self = self else { return }
                switch nav {
                case .showSpaceDetail(let space):
                    self.navigateToSpaceDetail(space)
                    self.store.dispatch(.resetNavigation)

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func navigateToSpaceDetail(_ space: StorachaSpace) {
        let fileListVC = FileListViewController(store: store, space: space)
          navigationController?.pushViewController(fileListVC, animated: true)
    }
    @objc func customBackTapped() {
        if let navigationController = self.navigationController {
            
            if let existingVC = navigationController.viewControllers.first(where: { $0 is StorachaSettingViewController }) {
                
                navigationController.popToViewController(existingVC, animated: true)
            } else {
                
                let newVC = MainViewController()
                navigationController.pushViewController(newVC, animated: true)
            }
        }
    }
}

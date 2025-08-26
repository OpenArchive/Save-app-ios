//
//  FileListViewController.swift
//  Save
//
//  Created by navoda on 2025-05-29.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit
import Combine
class FileListViewController: UIViewController {
    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private let space: StorachaSpaceTest

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, space: StorachaSpaceTest) {
        self.store = store
        self.space = space
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var viewModel: SpaceFilesViewModel?

    override func viewWillDisappear(_ animated: Bool) {
        store.dispatch(.resetNavigation)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = space.name
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Manage DIDs", style: .plain, target: self, action: #selector(manageDIDsTapped))
        viewModel = SpaceFilesViewModel(store: store, spaceId: space.id)
        if let viewModel = self.viewModel {
            let contentView = FileListView(viewModel: viewModel) {
                self.presentFilePicker()
            }

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

    private func presentFilePicker() {
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.delegate = self
            present(picker, animated: true)
        } else {
            // Fallback on earlier versions
        }
        
    }
    @objc func manageDIDsTapped() {
        let vc = ManageDIDsViewController(store: store, space: space)
              navigationController?.pushViewController(vc, animated: true)
    }
}

extension FileListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let picked = urls.first else { return }
        viewModel?.addFile(fileName: picked.lastPathComponent)
    }
}
class SpaceFilesViewModel: ObservableObject {
    @Published var files: [String] = []

    private let store: AccountsStore<AccountsAppState, AccountsAppAction>
    private let spaceId: String
    private var cancellables = Set<AnyCancellable>()

    init(store: AccountsStore<AccountsAppState, AccountsAppAction>, spaceId: String) {
        self.store = store
        self.spaceId = spaceId

        if #available(iOS 14.0, *) {
            store.$state
                .map { state in
                    let match = state.spaces.first(where: { $0.id == spaceId })
                    print("🔍 Looking for space with ID: \(spaceId)")
                    print("📦 Found space: \(String(describing: match))")
                    print("📄 Files: \(match?.files ?? [])")
                    return match?.files ?? []
                }
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .assign(to: &$files)
        }
    }

    func addFile(fileName: String) {
        store.dispatch(.addFile(toSpaceId: spaceId, fileName: fileName))
    }
}
import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: SpaceFilesViewModel
    let onUploadTapped: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Spacer().frame(height: 20)
            List(viewModel.files, id: \.self) { file in
                if #available(iOS 15.0, *) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.accentColor)
                        Text(file)
                            .font(.montserrat(.medium, for: .body))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(.systemBackground))
                    .listRowSeparator(.hidden)
                } else {
                   
                }
            }
            .listStyle(.plain)
            Spacer()
            Button(action: onUploadTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .padding(.horizontal)
            }

            .padding()
        }
    }
}

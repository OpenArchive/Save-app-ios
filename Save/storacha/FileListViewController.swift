//
//  FileListViewController 2.swift
//  Save
//
//  Created by navoda on 2025-08-31.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

class FileListViewController: UIViewController {
    private let appState: StorachaAppState
    private let space: StorachaSpace
    
    init(appState: StorachaAppState, space: StorachaSpace) {
        self.appState = appState
        self.space = space
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = space.name
        
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Manage DIDs",
            style: .plain,
            target: self,
            action: #selector(manageDIDsTapped)
        )
        
        if #available(iOS 14.0, *) {
            let contentView = FileListView(spaceDid: space.id) {
                self.presentFilePicker()
            }
            .environmentObject(appState.spaceState)
            
            let hosting = UIHostingController(rootView: contentView)
            addChild(hosting)
            view.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            hosting.didMove(toParent: self)
        }
    }
    
    private func presentFilePicker() {
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.delegate = self
            present(picker, animated: true)
        }
    }
    
    @objc func manageDIDsTapped() {
        let vc = ManageDIDsViewController(didState: appState.didState, spaceDid: space.id)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension FileListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let picked = urls.first else { return }
        print("Picked file: \(picked.lastPathComponent)")
        // TODO: Call APIService.uploadFile with picked data
    }
}

//
//  CreateCCLWrapperViewController.swift
//  Save
//
//  Created by Navoda on 2026-01-04.
//  Copyright © 2026 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

/// UIKit wrapper for CreateCCLView to maintain compatibility with existing navigation flow
@available(iOS 14.0, *)
class CreateCCLWrapperViewController: UIViewController, WizardDelegatable {

    weak var delegate: WizardDelegate?
    var space: Space?

    private var hostingController: UIHostingController<CreateCCLView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let space = space else {
            print("Error: No space provided to CreateCCLWrapperViewController")
            return
        }

        // Set navigation title based on space type
        if space is IaSpace {
            title = NSLocalizedString("Internet Archive", comment: "")
        } else {
            title = NSLocalizedString("Private Server", comment: "")
        }

        // Hide back button
        navigationItem.hidesBackButton = true

        // Create SwiftUI view
        let swiftUIView = CreateCCLView(space: space) { [weak self] serverName in
            self?.handleNext(serverName: serverName)
        }

        // Wrap in hosting controller
        let hosting = UIHostingController(rootView: swiftUIView)
        hostingController = hosting

        // Add as child view controller
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // Setup constraints
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        view.backgroundColor = .systemBackground
    }

    private func handleNext(serverName: String) {
        guard let space = space else { return }

        // Update space name if provided and wait for completion before navigating
        if !serverName.isEmpty && !(space is IaSpace) {
            // Update the local space object first
            space.name = serverName
            updateSpaceName(space: space) { [weak self] in
                self?.navigateToSuccess(space: space)
            }
        } else {
            navigateToSuccess(space: space)
        }
    }

    private func navigateToSuccess(space: Space) {
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
        if space is IaSpace {
            vc.spaceName = NSLocalizedString("the Internet Archive", comment: "")
        } else {
            vc.spaceName = NSLocalizedString("a private server", comment: "")
        }

        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateSpaceName(space: Space, completion: @escaping () -> Void) {
        // Update SelectedSpace reference immediately in memory

        if SelectedSpace.id == space.id {
            SelectedSpace.space = space
        }

        // Then save to database
        Db.writeConn?.asyncReadWrite({ tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)
            SelectedSpace.store(tx)
        }, completionBlock: {
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}

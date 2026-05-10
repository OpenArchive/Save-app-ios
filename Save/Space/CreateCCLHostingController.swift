//
//  CreateCCLHostingController.swift
//  Save
//
//  Hosts `CreateCCLView` and performs post-submit navigation (teal stack: inline title + back).
//

import SwiftUI
import UIKit
import YapDatabase

@available(iOS 14.0, *)
private final class CreateCCLNavHandler {
    weak var owner: CreateCCLHostingController?

    func handleNext(_ serverName: String) {
        owner?.performFlowNext(serverName: serverName)
    }
}

/// Hosts `CreateCCLView` and performs post-submit navigation.
@available(iOS 14.0, *)
final class CreateCCLHostingController: UIHostingController<CreateCCLView> {

    var space: Space?

    private let navHandler: CreateCCLNavHandler

    init(space: Space) {
        let handler = CreateCCLNavHandler()
        self.navHandler = handler
        self.space = space
        super.init(rootView: CreateCCLView(space: space, onNext: { handler.handleNext($0) }))
    }

    @objc required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navHandler.owner = self

        if space is IaSpace {
            title = NSLocalizedString("Internet Archive", comment: "")
        } else {
            title = NSLocalizedString("Private Server", comment: "")
        }
        save_configureTealStackNavigationItem()
        view.backgroundColor = .systemBackground
    }

    fileprivate func performFlowNext(serverName: String) {
        guard let space else { return }

        if !serverName.isEmpty && !(space is IaSpace) {
            space.name = serverName
            updateSpaceName(space: space) { [weak self] in
                self?.navigateToSuccess(space: space)
            }
        } else {
            navigateToSuccess(space: space)
        }
    }

    private func navigateToSuccess(space: Space) {
        let name: String
        if space is IaSpace {
            name = NSLocalizedString("the Internet Archive", comment: "")
        } else {
            name = NSLocalizedString("a private server", comment: "")
        }

        let vc = SpaceSuccessViewController(spaceName: name)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateSpaceName(space: Space, completion: @escaping () -> Void) {
        if SelectedSpace.id == space.id {
            SelectedSpace.space = space
        }

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

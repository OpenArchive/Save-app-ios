//
//  ServerListViewController.swift
//  Save
//
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

final class ServerListViewController: UIHostingController<ServerListView> {

    init() {
        super.init(rootView: ServerListView(onAddServer: {}, onSelectSpace: { _ in }))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Media Servers", comment: "")
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        rootView = ServerListView(
            onAddServer: {
                AppNavigationRouter.shared.pushSpaceType()
            },
            onSelectSpace: { [weak self] space in
                self?.editServer(space)
            }
        )
    }

    private func editServer(_ space: Space) {
        switch space {
        case let iaSpace as IaSpace:
            AppNavigationRouter.shared.pushInternetArchiveDetails(space: iaSpace)
        case let webDavSpace as WebDavSpace:
            AppNavigationRouter.shared.pushPrivateServerSetting(space: webDavSpace)
        default:
            #if DEBUG
            print("no navigation")
            #endif
        }
    }
}

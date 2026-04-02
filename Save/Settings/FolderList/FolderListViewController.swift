//
//  FolderListViewController.swift
//  Save
//
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

final class FolderListNewViewController: UIHostingController<FolderListView> {

    private let archived: Bool

    init(archived: Bool) {
        self.archived = archived
        super.init(rootView: FolderListView(archived: archived) { _ in })
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        let archived = aDecoder.decodeBool(forKey: "archived")
        self.archived = archived
        super.init(rootView: FolderListView(archived: archived) { _ in })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.title = NSLocalizedString("Archived Folders", comment: "")

        rootView = FolderListView(archived: archived) { [weak self] project in
            guard self != nil else { return }
            if #available(iOS 14.0, *) {
                AppNavigationRouter.shared.push(EditFolderViewController(project), animated: true)
            }
        }
    }

    override func encode(with coder: NSCoder) {
        coder.encode(archived, forKey: "archived")
        super.encode(with: coder)
    }
}

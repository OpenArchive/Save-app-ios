//
//  ManagementViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

final class ManagementViewController: UIHostingController<ManagementView> {

    weak var delegate: DoneDelegate?

    private let titleContainer = MultilineTitle()

    init(delegate: DoneDelegate? = nil) {
        self.delegate = delegate
        super.init(rootView: ManagementView(onDone: nil, onTitleChange: nil))
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        titleContainer.title.text = NSLocalizedString("Edit Queue", comment: "")
        titleContainer.subtitle.text = NSLocalizedString("Uploading is paused", comment: "")
        titleContainer.title.font = .montserrat(forTextStyle: .callout, with: .traitUIOptimized)
        titleContainer.subtitle.font = .montserrat(forTextStyle: .caption1)
        titleContainer.title.textColor = .label
        titleContainer.subtitle.textColor = .gray70
        navigationItem.titleView = titleContainer

        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = nil
        }

        let doneItem = UIBarButtonItem(
            title: NSLocalizedString("DONE", comment: ""),
            style: .plain,
            target: self,
            action: #selector(doneTapped)
        )
        if #available(iOS 26.0, *) {
            doneItem.hidesSharedBackground = true
        }
        navigationItem.rightBarButtonItem = doneItem

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        if let navBar = navigationController?.navigationBar {
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.compactAppearance = appearance
            navBar.isTranslucent = false
            navBar.tintColor = .label
        }

        rootView = ManagementView(
            onDone: { [weak self] in
                self?.delegate?.done()
            },
            onTitleChange: { [weak self] title, subtitle in
                self?.titleContainer.title.text = title
                self?.titleContainer.subtitle.text = subtitle
            }
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = .label
    }

    @objc private func doneTapped() {
        NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
        dismiss(animated: true)
    }
}

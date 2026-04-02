//
//  PrivateServerSettingViewController.swift
//  Save
//
//  Created by navoda on 2025-02-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 14.0, *)
final class PrivateServerNavigationBridge: ObservableObject {
    weak var viewController: PrivateServerSettingViewController?
    let space: Space

    init(space: Space) {
        self.space = space
    }

    func setBackHidden(_ hidden: Bool) {
        viewController?.navigationItem.hidesBackButton = hidden
    }

    func pop() {
        viewController?.navigationController?.popViewController(animated: true)
    }

    func setTitle(_ title: String) {
        viewController?.title = title
        viewController?.navigationItem.title = title
    }

    func setEditing(_ isEditing: Bool) {
        guard let vc = viewController else { return }
        vc.navigationItem.rightBarButtonItem = isEditing ? vc.makeConfirmBarButtonItem() : nil
    }
}

@available(iOS 14.0, *)
struct PrivateServerHostRoot: View {
    @ObservedObject var bridge: PrivateServerNavigationBridge

    var body: some View {
        PrivateServerSettingsView(
            space: bridge.space,
            disableBackAction: { bridge.setBackHidden($0) },
            dismissAction: { bridge.pop() },
            changeTitle: { bridge.setTitle($0) },
            onEditingChanged: { bridge.setEditing($0) }
        )
    }
}

@available(iOS 14.0, *)
final class PrivateServerSettingViewController: UIHostingController<PrivateServerHostRoot> {

    var space: Space { bridge.space }

    private let bridge: PrivateServerNavigationBridge

    init(space: Space) {
        let b = PrivateServerNavigationBridge(space: space)
        self.bridge = b
        super.init(rootView: PrivateServerHostRoot(bridge: b))
    }

    @objc required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.viewController = self

        save_configureTealStackNavigationItem()
        navigationItem.title = space.prettyName
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("PrivateServerDetails")
    }

    func makeConfirmBarButtonItem() -> UIBarButtonItem {
        SaveNavigationBarButtons.makeChromelessPrimaryActionBarButtonItem(
            title: NSLocalizedString("Confirm", comment: ""),
            target: self,
            action: #selector(confirmTapped)
        )
    }

    @objc func confirmTapped() {
        view.endEditing(true)
        NotificationCenter.default.post(
            name: Foundation.Notification.Name.privateServerSettingsConfirm,
            object: space.id
        )
    }
}

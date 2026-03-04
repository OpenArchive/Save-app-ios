//
//  MediaPickerSheetViewController.swift
//  Save
//
//  Created by navoda on 2025-03-25.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class MediaPopupViewController: UIHostingController<MediaPopupView> {

    var onCameraTap: (() -> Void)?
    var onGalleryTap: (() -> Void)?
    var onFilesTap: (() -> Void)?
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?

    required init() {
        let placeholder = MediaPopupView(
            onCameraTap: {},
            onGalleryTap: {},
            onFilesTap: {},
            onDismiss: {}
        )
        super.init(rootView: placeholder)
        modalPresentationStyle = .overCurrentContext
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView = MediaPopupView(
            onCameraTap: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.onCameraTap?()
                }
            },
            onGalleryTap: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.onGalleryTap?()
                }
            },
            onFilesTap: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.onFilesTap?()
                }
            },
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onAppear?()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onDisappear?()
    }
}

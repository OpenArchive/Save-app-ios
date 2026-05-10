//
//  CustomAlertHostedPresentation.swift
//  OpenArchive
//
//  Shared model + UIHostingController presentation for CustomAlertView (no CustomAlertViewController).
//

import SwiftUI
import UIKit

/// Payload for presenting the custom Save alert UI from any UIViewController via `UIHostingController`.
public struct CustomAlertPresentationModel {
    public let title: String
    public let message: String
    public let primaryButtonTitle: String
    public let primaryButtonAction: () -> Void
    public let secondaryButtonTitle: String?
    public let secondaryButtonAction: (() -> Void)?
    public let secondaryButtonIsOutlined: Bool
    public let showCheckbox: Bool
    public let iconImage: Image?
    public let iconTint: Color
    public let isRemoveAlert: Bool

    public init(
        title: String,
        message: String,
        primaryButtonTitle: String,
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonTitle: String? = nil,
        secondaryButtonAction: (() -> Void)? = nil,
        secondaryButtonIsOutlined: Bool = false,
        showCheckbox: Bool = false,
        iconImage: Image? = nil,
        iconTint: Color = .gray,
        isRemoveAlert: Bool = false
    ) {
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryButtonAction = secondaryButtonAction
        self.secondaryButtonIsOutlined = secondaryButtonIsOutlined
        self.showCheckbox = showCheckbox
        self.iconImage = iconImage
        self.iconTint = iconTint
        self.isRemoveAlert = isRemoveAlert
    }
}

/// Full-screen dim + `CustomAlertView` for modal presentation.
public struct CustomAlertFullScreenView: View {
    let model: CustomAlertPresentationModel
    let dismissOverlay: () -> Void

    public init(model: CustomAlertPresentationModel, dismissOverlay: @escaping () -> Void) {
        self.model = model
        self.dismissOverlay = dismissOverlay
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            CustomAlertView(
                title: model.title,
                message: model.message,
                primaryButtonTitle: model.primaryButtonTitle,
                iconImage: model.iconImage,
                iconTint: model.iconTint,
                primaryButtonAction: {
                    model.primaryButtonAction()
                    dismissOverlay()
                },
                secondaryButtonTitle: model.secondaryButtonTitle,
                secondaryButtonIsOutlined: model.secondaryButtonIsOutlined,
                secondaryButtonAction: model.secondaryButtonAction.map { action in
                    {
                        action()
                        dismissOverlay()
                    }
                },
                showCheckbox: model.showCheckbox,
                isRemoveAlert: model.isRemoveAlert
            )
        }
    }
}

public enum HostedCustomAlertPresenter {

    /// Presents the custom alert modally from `presenter` using `UIHostingController` (over full screen).
    public static func present(from presenter: UIViewController, model: CustomAlertPresentationModel, animated: Bool = true) {
        let host = UIHostingController(
            rootView: CustomAlertFullScreenView(model: model) {
                presenter.dismiss(animated: true)
            }
        )
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.view.backgroundColor = .clear
        presenter.present(host, animated: animated)
    }
}

extension UIApplication {

    /// Best-effort key window root’s frontmost view controller (for alerts with no explicit presenter).
    public static func keyWindowTopViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
            ?? scenes.flatMap(\.windows).first
        guard let root = window?.rootViewController else { return nil }
        return root.top
    }
}

//
//  CustomAlertPresenter.swift
//  Save
//
//  Routes custom alerts: Main overlay when on `MainHostingController`, else UIHostingController modal.
//

import SwiftUI
import UIKit

enum CustomAlertPresenter {

    /// Presents a custom alert. Uses `AppOverlayState` when `presenter` is (or resolves to) `MainHostingController`.
    static func present(_ model: CustomAlertPresentationModel, from presenter: UIViewController? = nil) {
        DispatchQueue.main.async {
            let target = presenter ?? UIApplication.keyWindowTopViewController()
            guard let vc = target else { return }
            if vc is MainHostingController {
                AppOverlayState.shared.present(model)
            } else {
                HostedCustomAlertPresenter.present(from: vc, model: model)
            }
        }
    }
}

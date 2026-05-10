//
//  AppOverlayState.swift
//  Save
//
//  Single overlay for CustomAlert on the main SwiftUI shell (MainView).
//

import Combine
import SwiftUI

/// Drives the in-`MainView` overlays: custom alerts and toasts (see `CustomAlertPresenter` for alert routing).
///
/// **Stacking policy:** Only one custom alert is shown at a time. Calling `present(_:)` **replaces** any
/// existing alert immediately (no queue). If you need sequential alerts, chain from the previous
/// button handler after `dismiss()` or present the next model in the primary/secondary action.
///
/// Toasts auto-clear after `duration`; a new `showToast` replaces the previous toast timer.
final class AppOverlayState: ObservableObject {
    static let shared = AppOverlayState()

    @Published private(set) var activePresentation: CustomAlertPresentationModel?
    @Published private(set) var toastMessage: String?

    private var toastDismissWorkItem: DispatchWorkItem?

    private init() {}

    /// Shows `model` in the main-shell overlay, replacing any current alert.
    func present(_ model: CustomAlertPresentationModel) {
        DispatchQueue.main.async { [weak self] in
            self?.activePresentation = model
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.activePresentation = nil
        }
    }

    /// Shows a bottom toast on the main SwiftUI shell (same layer as `MainView`).
    func showToast(message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.toastDismissWorkItem?.cancel()
            self.toastMessage = message
            let work = DispatchWorkItem { [weak self] in
                self?.toastMessage = nil
            }
            self.toastDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }
}

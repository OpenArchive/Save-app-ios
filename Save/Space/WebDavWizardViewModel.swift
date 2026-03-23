//
//  WebDavWizardViewModel.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
final class WebDavWizardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var urlString: String = "" {
        didSet { validate(); clearErrors() }
    }

    @Published var username: String = "" {
        didSet { validate(); clearErrors() }
    }

    @Published var password: String = "" {
        didSet { validate(); clearErrors() }
    }

    @Published private(set) var isBusy = false
    @Published private(set) var isValid = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var showServerNotFoundAlert = false
    @Published private(set) var showDuplicateCredentialsAlert = false
    @Published private(set) var urlHasError = false
    @Published private(set) var usernameHasError = false
    @Published private(set) var passwordHasError = false

    // MARK: - Callbacks

    var onSuccess: ((WebDavSpace) -> Void)?
    var onCancel: (() -> Void)?
    var onBusyChanged: ((Bool) -> Void)?

    // MARK: - Computed Properties

    private var url: URL? {
        Formatters.URLFormatter.fix(url: urlString)
    }

    // MARK: - Public Methods

    func fixUrlOnCommit() {
        if let fixed = Formatters.URLFormatter.fix(url: urlString)?.absoluteString {
            urlString = fixed
        }
    }

    func connect() {
        guard !isBusy, isValid, let url else { return }

        setBusy(true)
        canOpen(url.absoluteString) { [weak self] reachable in
            Task { @MainActor in
                guard let self else { return }
                self.setBusy(false)

                if reachable {
                    await self.handleReachableServer()
                } else {
                    self.showServerNotFoundError()
                }
            }
        }
    }

    func cancel() {
        onCancel?()
    }

    func dismissServerNotFoundAlert() {
        showServerNotFoundAlert = false
    }

    func dismissDuplicateCredentialsAlert() {
        showDuplicateCredentialsAlert = false
    }

    // MARK: - Private Methods

    private func validate() {
        isValid = !urlString.isEmpty
            && !username.isEmpty
            && !password.isEmpty
            && url != nil
    }

    private func clearErrors() {
        errorMessage = ""
        urlHasError = false
        usernameHasError = false
        passwordHasError = false
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        onBusyChanged?(busy)
    }

    private func showServerNotFoundError() {
        urlHasError = true
        showServerNotFoundAlert = true
    }

    private func showDuplicateCredentialsError() {
        usernameHasError = true
        showDuplicateCredentialsAlert = true
    }

    private func showCredentialsError(_ message: String) {
        usernameHasError = true
        passwordHasError = true
        errorMessage = message
    }

    private func handleReachableServer() async {
        if spaceExists(username: username) {
            showDuplicateCredentialsError()
            return
        }
        await verifyAndSaveSpace()
    }

    private func spaceExists(username: String) -> Bool {
        var exists = false
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Space.collection) { (_: String, space: Space, stop: inout Bool) in
                if space.username?.lowercased() == username.lowercased() {
                    exists = true
                    stop = true
                }
            }
        }
        return exists
    }

    private func verifyAndSaveSpace() async {
        guard let url else { return }

        let space = WebDavSpace(
            name: "",
            url: url,
            favIcon: UIImage(named: "private_server"),
            username: username,
            password: password
        )

        setBusy(true)

        let (_, error) = await withCheckedContinuation { (continuation: CheckedContinuation<([FileInfo], Error?), Never>) in
            URLSession(configuration: UploadManager.improvedSessionConf())
                .info(space.url!, credential: space.credential) { info, error in
                    continuation.resume(returning: (info, error))
                }
        }

        await MainActor.run { setBusy(false) }

        if let error {
            if error.localizedDescription.contains("404") {
                showServerNotFoundError()
            } else {
                showCredentialsError(error.friendlyMessage)
            }
            return
        }

        SelectedSpace.space = space
        errorMessage = ""

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Db.writeConn?.asyncReadWrite(
                { tx in
                    SelectedSpace.store(tx)
                    tx.setObject(space)
                },
                completionBlock: { continuation.resume() }
            )
        }

        trackEvent(.backendConfigured(backendType: "WebDAV", isNew: true))
        onSuccess?(space)
    }

    private func canOpen(_ urlString: String, completion: @escaping @Sendable (Bool) -> Void) {
        guard let url = URL(string: urlString),
              let host = url.host, !host.isEmpty
        else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { _, response, _ in
            completion(response != nil)
        }.resume()
    }
}

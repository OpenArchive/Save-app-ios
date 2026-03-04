//
//  InternetArchiveDetailViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Updated by Navoda on 2025-09-03
//

import Foundation

final class InternetArchiveDetailViewModel: ObservableObject {

    let space: Space

    @Published var screenName: String = ""
    @Published var userName: String = ""
    @Published var email: String = ""
    @Published var isCcEnabled: Bool = false
    @Published var isCc0Enabled: Bool = false
    @Published var allowRemix: Bool = false
    @Published var requireShareAlike: Bool = false
    @Published var allowCommercialUse: Bool = false
    @Published var licenseURL: String?

    /// Called when the space is removed or flow should dismiss (e.g. Cancel).
    var onDismiss: (() -> Void)?
    /// Called with true to hide back button, false to show it (e.g. when "Remove" alert is shown).
    var onBackButtonVisibility: ((Bool) -> Void)?

    init(space: Space) {
        self.space = space
        load()
    }

    // MARK: - License toggles (replace reducer actions)

    func toggleCcEnabled(_ value: Bool) {
        isCcEnabled = value
        if !value {
            isCc0Enabled = false
            allowRemix = false
            requireShareAlike = false
            allowCommercialUse = false
        }
        updateLicense()
    }

    func toggleCc0Enabled(_ value: Bool) {
        isCc0Enabled = value
        if value {
            allowRemix = false
            requireShareAlike = false
            allowCommercialUse = false
        }
        updateLicense()
    }

    func toggleAllowRemix(_ value: Bool) {
        allowRemix = value
        if value {
            // keep requireShareAlike as-is
        } else {
            requireShareAlike = false
        }
        isCc0Enabled = false
        updateLicense()
    }

    func toggleRequireShareAlike(_ value: Bool) {
        requireShareAlike = value
        if value { isCc0Enabled = false }
        updateLicense()
    }

    func toggleAllowCommercialUse(_ value: Bool) {
        allowCommercialUse = value
        if value { isCc0Enabled = false }
        updateLicense()
    }

    func setBackButtonVisibility(_ hidden: Bool) {
        onBackButtonVisibility?(hidden)
    }

    func removeSpace() {
        remove()
    }

    // MARK: - Load

    private func load() {
        let decoder = JSONDecoder()
        guard let data = (space as? IaSpace)?.metaData?.data(using: .utf8) else { return }
        guard let metaData = try? decoder.decode(InternetArchive.MetaData.self, from: data) else { return }

        screenName = metaData.screenName
        userName = metaData.userName
        email = metaData.email
        isCcEnabled = space.license != nil
        isCc0Enabled = space.license?.contains("publicdomain/zero") == true
        allowRemix = isCc0Enabled ? false : (space.license?.contains("-nd") == false)
        requireShareAlike = isCc0Enabled ? false : (space.license?.contains("-sa") == true)
        allowCommercialUse = isCc0Enabled ? false : (space.license?.contains("-nc") == false)
        licenseURL = space.license
    }

    // MARK: - License URL

    private func updateLicense() {
        let url = generateLicenseURL()
        #if DEBUG
        print(url ?? "")
        #endif
        saveLicense(licenseURL: url)
        licenseURL = url
    }

    private func saveLicense(licenseURL: String?) {
        guard let space = space as? IaSpace else { return }
        space.license = licenseURL
        Db.writeConn?.asyncReadWrite { tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)
            let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }
            for project in projects {
                project.license = space.license
                tx.setObject(project)
            }
        }
    }

    private func remove() {
        guard let writeConn = Db.writeConn else { return }
        writeConn.readWrite { tx in
            tx.removeObject(forKey: space.id, inCollection: Space.collection)
            SelectedSpace.space = nil
            SelectedSpace.store(tx)
            tx.iterateKeysAndObjects(inCollection: Space.collection) { (_: String, space: Space, stop: inout Bool) in
                SelectedSpace.space = space
                stop = true
            }
            SelectedSpace.store(tx)
        }
        onDismiss?()
    }

    private func generateLicenseURL() -> String? {
        guard isCcEnabled else { return nil }
        if isCc0Enabled {
            return "https://creativecommons.org/publicdomain/zero/1.0/"
        }
        var license = "by"
        if allowRemix {
            if !allowCommercialUse { license += "-nc" }
            if requireShareAlike { license += "-sa" }
        } else {
            if !allowCommercialUse { license += "-nc" }
            license += "-nd"
        }
        return "https://creativecommons.org/licenses/\(license)/4.0/"
    }
}

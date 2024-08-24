//
//  CcSelector.swift
//  Save
//
//  Created by Benjamin Erhart on 09.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import Eureka

class CcSelector {

    static let ccDomain = "creativecommons.org"
    static let ccUrl = "https://%@/licenses/%@/4.0/"

    lazy var ccSw = SwitchRow("cc") {
        $0.title = individual
            ? NSLocalizedString("Set unique Creative Commons licenses for EACH INDIVIDUAL folder on this server.", comment: "")
            : NSLocalizedString("Set the same Creative Commons license for ALL folders on this server.", comment: "")

        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent

        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }

    lazy var remixSw = SwitchRow("remixSw") {
        $0.title = NSLocalizedString("Allow anyone to remix and share?", comment: "")

        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent

        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }

    lazy var shareAlikeSw = SwitchRow() {
        $0.title = NSLocalizedString("Require them to share like you have?", comment: "")

        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent

        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc", "remixSw"], { [weak self] _ in
            !(self?.enabled ?? false) || !(self?.remixSw.value ?? false)
        })
    }

    lazy var commercialSw = SwitchRow() {
        $0.title = NSLocalizedString("Allow commercial use?", comment: "")

        $0.cell.textLabel?.numberOfLines = 0
        $0.cell.switchControl.onTintColor = .accent

        $0.hidden = "$cc != true"
        $0.disabled = .function(["cc"], { [weak self] _ in
            !(self?.enabled ?? false)
        })
    }

    let licenseRow = LinkRow() {
        $0.cell.textLabel?.adjustsFontSizeToFitWidth = true
        $0.cell.backgroundColor = .clear
        $0.hidden = "$cc != true"
    }

    let learnMoreRow = LinkRow() {
        $0.title = NSLocalizedString("Learn more about Creative Commons", comment: "")
        $0.value = URL(string: "https://creativecommons.org/about/cclicenses/")

        $0.cell.textLabel?.numberOfLines = 0

        $0.hidden = "$cc != true"
    }


    private let individual: Bool

    private var enabled = true


    init(individual: Bool) {
        self.individual = individual
    }


    // MARK: Methods

    func set(_ license: String?, enabled: Bool = true) {
        if let license = license, license.localizedCaseInsensitiveContains(Self.ccDomain) {
            ccSw.value = true
            remixSw.value = !license.localizedCaseInsensitiveContains("-nd")
            shareAlikeSw.value = !shareAlikeSw.isDisabled && license.localizedCaseInsensitiveContains("-sa")
            commercialSw.value = !license.localizedCaseInsensitiveContains("-nc")
            licenseRow.title = license
            licenseRow.value = URL(string: license)
        }
        else {
            ccSw.value = false
        }

        self.enabled = enabled
        ccSw.evaluateDisabled()
        remixSw.evaluateDisabled()
        shareAlikeSw.evaluateDisabled()
        commercialSw.evaluateDisabled()
    }

    func get() -> String? {
        var license: String? = nil

        if ccSw.value ?? false {
            license = "by"

            if remixSw.value ?? false {
                if !(commercialSw.value ?? false) {
                    license! += "-nc"
                }

                if shareAlikeSw.value ?? false {
                    license! += "-sa"
                }
            } else {
                shareAlikeSw.value = false

                if !(commercialSw.value ?? false) {
                    license! += "-nc"
                }

                license! += "-nd"
            }

            license = String(format: Self.ccUrl, Self.ccDomain, license!)
        }

        licenseRow.title = license
        licenseRow.value = license != nil ? URL(string: license!) : nil
        licenseRow.updateCell()

        return license
    }
}

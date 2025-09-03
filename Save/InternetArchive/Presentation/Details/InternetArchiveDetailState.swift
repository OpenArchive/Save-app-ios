//
//  InternetArchiveDetailState.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//

struct InternetArchiveDetailState {
    private(set) var screenName: String = ""
    private(set) var userName: String = ""
    private(set) var email: String = ""

    // Creative Commons license state
    var isCcEnabled: Bool = false
    var allowRemix: Bool = false
    var requireShareAlike: Bool = false
    var allowCommercialUse: Bool = false
    var licenseURL: String? = nil

    func copy(
        screenName: String? = nil,
        userName: String? = nil,
        email: String? = nil,
        isCcEnabled: Bool? = nil,
        allowRemix: Bool? = nil,
        requireShareAlike: Bool? = nil,
        allowCommercialUse: Bool? = nil,
        licenseURL: String? = nil
    ) -> InternetArchiveDetailState {
        var copy = self
        copy.screenName = screenName ?? self.screenName
        copy.userName = userName ?? self.userName
        copy.email = email ?? self.email
        copy.isCcEnabled = isCcEnabled ?? self.isCcEnabled
        copy.allowRemix = allowRemix ?? self.allowRemix
        copy.requireShareAlike = requireShareAlike ?? self.requireShareAlike
        copy.allowCommercialUse = allowCommercialUse ?? self.allowCommercialUse
        copy.licenseURL = licenseURL ?? self.licenseURL
        return copy
    }
}

enum InternetArchiveDetailAction {
    case Load
    case Loaded(_ metaData: InternetArchive.MetaData)
    case Remove
    case Removed
    case Cancel
    case HandleBackButton(status: Bool)

    case toggleCcEnabled(Bool)
    case toggleAllowRemix(Bool)
    case toggleRequireShareAlike(Bool)
    case toggleAllowCommercialUse(Bool)
    case updateLicense
}


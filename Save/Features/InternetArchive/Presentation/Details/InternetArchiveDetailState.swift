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
    
    func copy(
        screenName: String? = nil,
        userName: String? = nil,
        email: String? = nil
    ) -> InternetArchiveDetailState {
        var copy = self
        copy.screenName = screenName ?? self.screenName
        copy.userName = userName ?? self.userName
        copy.email = email ?? self.email
        return copy
    }
}

enum  InternetArchiveDetailAction {
    case Load
    case Loaded(_ metaData: InternetArchive.MetaData)
    case Remove
    case Removed
    case Cancel
    case HandleBackButton(status:Bool)
}

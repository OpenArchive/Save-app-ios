//
//  InternetArchiveFeature.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Factory


extension Container {
    var internetArchiveRemoteDataSource: Factory<InternetArchiveRemoteSource> {
        self { InternetArchiveRemoteSource() }
    }
    
    var internetArchiveMapper: Factory<InternetArchiveMapper> {
        self { InternetArchiveMapper() }
    }
    
    var internetArchiveRepository: Factory<InternetArchiveRepository> {
        self {
            InternetArchiveRepository(
                remoteDataSource: self.internetArchiveRemoteDataSource(),
                mapper: self.internetArchiveMapper()
            )
        }
    }
    
    var internetArchiveViewModel: Factory<InternetArchiveLoginViewModel> {
        self {
            InternetArchiveLoginViewModel(repository: self.internetArchiveRepository())
        }
    }
}

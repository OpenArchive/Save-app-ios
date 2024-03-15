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
    
    var internetArchiveLoginUseCase: Factory<InternetArchiveLoginUseCase> {
        self {
            InternetArchiveLoginUseCase(repository: self.internetArchiveRepository())
        }
    }
    
    var internetArchiveViewModel: ParameterFactory<StoreScope, InternetArchiveLoginViewModel> {
        self {
            InternetArchiveLoginViewModel(scope: $0, useCase: self.internetArchiveLoginUseCase())
        }
    }
}

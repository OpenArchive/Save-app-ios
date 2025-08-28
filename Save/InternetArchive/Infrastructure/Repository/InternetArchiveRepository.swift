//
//  InternetArchiveRepository.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine

class InternetArchiveRepository {
    
    private let remoteDataSource: InternetArchiveRemoteSource
    private let mapper: InternetArchiveMapper
    
    init(remoteDataSource: InternetArchiveRemoteSource, mapper: InternetArchiveMapper) {
        self.remoteDataSource = remoteDataSource
        self.mapper = mapper
    }
    
    enum LoginError : Error {
        case invalidResponse
        case dataSource(Error)
    }
    
    func login(email: String, password: String) -> AnyPublisher<InternetArchive, Error> {
        remoteDataSource.login(request: InternetArchiveLoginRequest(email: email, password: password))
            .tryCatch { err in
                Fail<InternetArchiveLoginResponse, Error>(error: err)
            }
            .tryMap { response in
                guard let data = self.mapper.map(response: response) else {
                    throw LoginError.invalidResponse
                }
                return data
            }.eraseToAnyPublisher()
    }
}

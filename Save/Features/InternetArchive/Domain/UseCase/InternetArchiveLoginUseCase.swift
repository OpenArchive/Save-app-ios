//
//  InternetArchiveLoginUseCase.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import CleanInsightsSDK
import Combine

class InternetArchiveLoginUseCase {

    private let repository: InternetArchiveRepository
    
    init(repository: InternetArchiveRepository) {
        self.repository = repository
    }
    
    func callAsFunction(
        email: String,
        password: String, 
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Scoped? {
        
        return repository.login(email: email, password: password)
            .sink(receiveCompletion: { result in
                switch result {
                case .finished:
                    completion(.success(()))
                case .failure(let err):
                    completion(.failure(err))
                }
            }, receiveValue: { result in
                
                let space = IaSpace(accessKey: result.auth.access, secretKey: result.auth.secret)
                
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(result.metaData) {
                    space.metaData = String(data: data, encoding: .utf8)
                }
                SelectedSpace.space = space

                Db.writeConn?.asyncReadWrite() { tx in
                    SelectedSpace.store(tx)

                    tx.setObject(space)
                }

                CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: space.name)

            })
    }
}

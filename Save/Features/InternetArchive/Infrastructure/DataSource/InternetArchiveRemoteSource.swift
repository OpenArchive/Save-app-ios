//
//  InternetArchiveRemoteSource.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation
import Combine

class InternetArchiveRemoteSource {
    
    private let LOGIN_URI = "https://archive.org/services/xauthn?op=login"

    func login(request: InternetArchiveLoginRequest) -> AnyPublisher<InternetArchiveLoginResponse, Error> {
        
        var urlRequest = URLRequest(url: URL(string: LOGIN_URI)!)
        
        let payload = [
            "email": request.email,
            "password": request.password
        ].toFormUrlEncodedString()?.data(using: .utf8)
        
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = payload
         
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                
                guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode) else {
                    throw DataSourceError.invalidResponse
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                guard let response = try? decoder.decode(InternetArchiveLoginResponse.self, from: data) else {
                    throw DataSourceError.decoding
                }
                
                return response
            }.eraseToAnyPublisher()
    }
    
}

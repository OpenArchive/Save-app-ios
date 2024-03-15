//
//  Dictionary+Utils.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

extension Dictionary<String, Any> {
    
    func toFormUrlEncodedString() -> String? {
        var components = URLComponents()
        components.queryItems = self.map { (key, value) in
            URLQueryItem(name: key, value: String(describing: value))
        }

        return components.query
    }
}

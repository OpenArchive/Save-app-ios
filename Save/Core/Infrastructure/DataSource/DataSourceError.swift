//
//  DataSourceError.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

enum DataSourceError: Error {
    case invalidResponse
    case decoding
    case network(Error)
}

//
//  ScopedViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Foundation

protocol ScopedViewModel {
    var scope: StoreScope { get }
}

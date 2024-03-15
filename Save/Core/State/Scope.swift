//
//  Scope.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//
import Combine

typealias Scoped = AnyCancellable

typealias StoreScope = Set<Scoped>


extension StoreScope {
    func cancel() {
        forEach { scope in scope.cancel() }
    }
}

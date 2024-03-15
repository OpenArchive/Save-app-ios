//
//  Stateful.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

protocol Stateful<State> {
    associatedtype State
    
    var state: State { get }
}

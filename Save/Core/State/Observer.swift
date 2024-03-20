//
//  Observer.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

protocol Notifier<Action> {
    associatedtype Action
    
    func notify(_ action: Action)
}

protocol Listener<Action> {
    associatedtype Action
    
    func listen(_ onAction: @escaping (Action) -> Void)
}


//
//  Dispatcher.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

protocol Dispatcher<Action> {
    associatedtype Action
    
    func dispatch(_ action: Action)
}

protocol Notifier<Action> {
    associatedtype Action
    
    func notify(_ action: Action)
}

protocol Listener<Action> {
    associatedtype Action
    
    func listen(_ onAction: @escaping (Action) -> Void)
}

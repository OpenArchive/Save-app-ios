//
//  StateListener.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Combine

class StateListener<Action> : Notifier, Listener {
    private let actions = PassthroughSubject<Action, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    func notify(_ action: Action) {
        actions.send(action)
    }
    
    func listen(_ onAction: @escaping (Action) -> Void) {
        actions.sink(receiveValue: onAction).store(in: &cancellables)
    }
}

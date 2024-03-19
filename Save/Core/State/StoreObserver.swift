//
//  StateListener.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Combine

class StoreObserver<Action> : Notifier, Listener {
    private let actions = PassthroughSubject<Action, Never>()
    
    func notify(_ action: Action) {
        actions.send(action)
    }
    
    func listen(_ onAction: @escaping (Action) -> Void) -> Scoped {
        return actions.receive(on: DispatchQueue.main).sink(receiveValue: onAction)
    }
}

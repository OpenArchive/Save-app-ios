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

    private var scope: StoreScope
    
    init(scope: StoreScope = StoreScope()) {
        self.scope = scope
    }
    
    func notify(_ action: Action) {
        actions.send(action)
    }
    
    func listen(_ onAction: @escaping (Action) -> Void) {
        actions.receive(on: DispatchQueue.main).sink(receiveValue: { action in 
            DispatchQueue.global().async {
                DispatchQueue.main.async {
                    onAction(action)
                }
            }
        }).store(in: &scope)
    }
}

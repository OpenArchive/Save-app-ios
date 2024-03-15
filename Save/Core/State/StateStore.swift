//
//  StateStore.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

class StateStore<State, Action>: Stateful, Store {
    
    private let dispatcher: StateDispatcher<State, Action>
    private let listener: StoreObserver<Action>
    
    init(scope: StoreScope, initialState: State, reducer:  @escaping Reducer<State, Action>, effects: @escaping Effects<State, Action>) {
        self.dispatcher = StateDispatcher(scope: scope, initialState: initialState, reducer: reducer, effects: effects)
        self.listener = StoreObserver<Action>(scope: scope)
    }
    
    lazy var state: State = { self.dispatcher.state }()
    
    func dispatch(_ action: Action) {
        dispatcher.dispatch(action)
    }
    
    func callAsFunction(_ action: Action) {
        dispatcher.dispatch(action)
    }
    
    func notify(_ action: Action) {
        listener.notify(action)
    }
    
    func listen(_ onAction: @escaping (Action) -> Void) {
        listener.listen(onAction)
    }
}

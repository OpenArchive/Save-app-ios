//
//  Store.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

protocol Store<Action>: Dispatcher, Notifier, Listener {
    func callAsFunction(_ action: Action)
}

class StateStore<State, Action>: Stateful, Store {
    
    private let dispatcher: StateDispatcher<State, Action>
    private let listener: StateListener<Action>
    
    init(initialState: State, reducer:  @escaping Reducer<State, Action>, effects: @escaping Effects<State, Action>) {
        self.dispatcher = StateDispatcher(initialState: initialState, reducer: reducer, effects: effects)
        self.listener = StateListener<Action>()
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

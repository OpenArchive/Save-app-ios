//
//  StateStore.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

class StateStore<State, Action>: Store {
    
    private(set) var dispatcher: StateDispatcher<State, Action>
    private(set) var listener: StoreObserver<Action>
    private var scope = StoreScope()
    
    init(initialState: State, reducer:  Reducer<State, Action>? = nil, effects: Effects<State, Action>? = nil) {
        
        self.dispatcher = StateDispatcher(initialState: initialState, reducer: reducer, effects: effects)
        self.listener = StoreObserver<Action>()
        
        self.scope.insert(self.dispatcher.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        })
    }
    
    func dispatch(_ action: Action) {
        dispatcher.dispatch(action)
    }
    
    func callAsFunction(_ action: Action) {
        dispatcher.dispatch(action)
    }
    
    func callAsFunction() -> State {
        return dispatcher.state
    }
    
    func notify(_ action: Action) {
        listener.notify(action)
    }
    
    func listen(_ onAction: @escaping (Action) -> Void) {
        listener.listen(onAction)
    }
    
    func set(reducer: @escaping Reducer<State, Action>) {
        self.dispatcher.reducer = reducer
    }
    
    func set(effects: @escaping Effects<State, Action>) {
        self.dispatcher.effects = effects
    }
}

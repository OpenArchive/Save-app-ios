//
//  StateDispatcher.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Combine

class StateDispatcher<State, Action>: Dispatcher, Stateful, ObservableObject {
    
    var reducer: Reducer<State,Action>?
    var effects: Effects<State, Action>?
    
    @Published private(set) var state: State
    
    private var scope: StoreScope
    
    init(
        scope: StoreScope = StoreScope(),
        initialState: State,
        reducer: Reducer<State, Action>? = nil,
        effects: Effects<State, Action>? = nil
    ) {
        self.scope = scope
        self.state = initialState
        self.reducer = reducer
        self.effects = effects
    }
    
    func dispatch(_ action: Action) {
        if let state = reducer?(self.state, action) {
            self.objectWillChange.send()
            self.state = state
        }
        
        if let effect = effects?(self.state, action) {
           effect.store(in: &scope)
        }
    }
}

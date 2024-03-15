//
//  StateDispatcher.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-13.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Combine

class StateDispatcher<State, Action>: Dispatcher, Stateful {
    
    private var reducer: Reducer<State,Action>
    private let effects: Effects<State, Action>
    
    private(set) var state: State
    
    private var scope: StoreScope
    
    init(
        scope: StoreScope,
        initialState: State,
        reducer: @escaping Reducer<State, Action>,
        effects: @escaping Effects<State, Action>
    ) {
        self.scope = scope
        self.state = initialState
        self.reducer = reducer
        self.effects = effects
    }
    
    func dispatch(_ action: Action) {
        state = reducer(state, action)
        
        effects(state, action).store(in: &scope)
    }
}

//
//  ScopedViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import SwiftUI

class StoreViewModel<State, Action> : ObservableObject {

    private(set) var store: StateStore<State, Action>
    
    private var scope: StoreScope
    
    init(
        scope: StoreScope = StoreScope(),
        initialState: State,
        reducer: Reducer<State, Action>? = nil,
        effects: Effects<State, Action>? = nil
    ) {
        self.scope = scope
        
        self.store = StateStore(initialState: initialState, reducer: reducer, effects: effects)
        
        self.scope.insert(self.store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        })
    }
}

extension StateStore {
    
    func bind<T>(_ keyPath: KeyPath<State, T>, _ set: @escaping (T) -> Action) -> Binding<T> {
        return Binding(
            get: { self.dispatcher.state[keyPath: keyPath] },
            set: { self.dispatcher.dispatch(set($0))}
        )
    }
    
    func bind<T>(_ keyPath: KeyPath<State, T>) -> () -> T {
        return { self.dispatcher.state[keyPath: keyPath] }
    }
}

//
//  Reducer.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-15.
//  Copyright © 2024 Open Archive. All rights reserved.
//

typealias Reducer<State, Action> = (State, Action) -> State?


func combine<S, A>(_ first: @escaping Reducer<S, A>, _ second: @escaping Reducer<S, A>) -> Reducer<S, A> {
    return { state, action in
        second(first(state, action) ?? state, action)
    }
}

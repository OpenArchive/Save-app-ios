//
//  Store.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//
import Combine

protocol Store<Action>: Dispatcher, Notifier, Listener, ObservableObject {
    func callAsFunction(_ action: Action)
}

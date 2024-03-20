//
//  Effects.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-14.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import Combine

typealias Effects<State, Action> = (State, Action) -> Scoped?

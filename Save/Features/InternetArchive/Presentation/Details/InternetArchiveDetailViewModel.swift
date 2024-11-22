//
//  InternetArchiveDetailViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//


class InternetArchiveDetailViewModel : StoreViewModel<InternetArchiveDetailState, InternetArchiveDetailAction> {
    typealias State = InternetArchiveDetailState
    typealias Action = InternetArchiveDetailAction
    
    let space: Space
    
    init(space: Space) {
        self.space = space
        
        super.init(initialState: InternetArchiveDetailState())
        
        self.store.set(reducer: self.reduce)
        self.store.set(effects: self.effects)
        
        self.store.dispatch(.Load)
    }
    
    
    // updates read-only state, copying structs is effecient in swift, but could be inout
    private func reduce(state: State, action: Action) -> State? {
        return switch action {
        case .Loaded(let data):
            state.copy(screenName: data.screenName, userName: data.userName, email: data.email)
        default: nil
        }
    }
    
    // applies side effects to store state and returns a value to keep in scope
    private func effects(state: State, action: Action) -> Scoped? {
        switch action {
        case .Load:
            load()
        case .Remove:
            remove()
        default: break
        }
        
        return nil
    }
    
    private func load() {
        let decoder = JSONDecoder()
        guard let data: Data = (space as? IaSpace)?.metaData?.data(using: .utf8)  else { return }
        
        if let metaData = try? decoder.decode(InternetArchive.MetaData.self, from: data) {
            self.store.dispatch(.Loaded(metaData))
        }
    }
    
    private func remove() {
        Db.writeConn?.readWrite { tx in
            tx.removeObject(forKey: space.id, inCollection: Space.collection)

            // Delete selected space, too.
            SelectedSpace.space = nil
            SelectedSpace.store(tx)

            // Find new selected space.
            tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
                SelectedSpace.space = space
                stop = true
            }

            // Store newly selected space.
            SelectedSpace.store(tx)
            
            self.store.notify(.Removed)
        }
    }
}

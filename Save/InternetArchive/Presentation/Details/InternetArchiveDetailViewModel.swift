//
//  InternetArchiveDetailViewModel.swift
//  Save
//
//  Created by Ryan Jennings on 2024-03-19.
//  Updated by Navoda on 2025-09-03
//

import Foundation

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
    
    // MARK: - Reducer
    private func reduce(state: State, action: Action) -> State? {
        switch action {
        case .Loaded(let data):
            let isCC0 = space.license?.contains("publicdomain/zero") == true
            
            return state.copy(
                screenName: data.screenName,
                userName: data.userName,
                email: data.email,
                isCcEnabled: space.license != nil,
                isCc0Enabled: isCC0, // New CC0 state
                allowRemix: isCC0 ? false : space.license?.contains("-nd") == false,
                requireShareAlike: isCC0 ? false : space.license?.contains("-sa") == true,
                allowCommercialUse: isCC0 ? false : space.license?.contains("-nc") == false,
                licenseURL: space.license
            )
            
        case .toggleCcEnabled(let value):
            var newState = state.copy(isCcEnabled: value)
            if !value {
                
                newState = newState.copy(
                    isCc0Enabled: false,
                    allowRemix: false,
                    requireShareAlike: false,
                    allowCommercialUse: false
                )
            }
            return newState
            
        case .toggleCc0Enabled(let value):
            var newState = state.copy(isCc0Enabled: value)
            if value {
                
                newState = newState.copy(
                    allowRemix: false,
                    requireShareAlike: false,
                    allowCommercialUse: false
                )
            }
            return newState
            
        case .toggleAllowRemix(let value):
            var newState = state.copy(
                allowRemix: value,
                requireShareAlike: value ? state.requireShareAlike : false
            )
            
            if value {
                newState = newState.copy(isCc0Enabled: false)
            }
            return newState
            
        case .toggleRequireShareAlike(let value):
            var newState = state.copy(requireShareAlike: value)
            
            if value {
                newState = newState.copy(isCc0Enabled: false)
            }
            return newState
            
        case .toggleAllowCommercialUse(let value):
            var newState = state.copy(allowCommercialUse: value)
            
            if value {
                newState = newState.copy(isCc0Enabled: false)
            }
            return newState
            
        case .updateLicense:
            var licence = generateLicenseURL(state: state)
            #if DEBUG
            print(licence)
            #endif
            saveLicense(licenseURL: licence)
            return state.copy(licenseURL:licence )
            
        default:
            return nil
        }
    }
    
    // MARK: - Effects
    private func effects(state: State, action: Action) -> Scoped? {
        switch action {
        case .Load:
            load()
            
        case .Remove:
            remove()
            
        case .HandleBackButton(let status):
            self.store.notify(.HandleBackButton(status: status))
            
        default:
            break
        }
        return nil
    }
    
    // MARK: - Load Account Info
    private func load() {
        let decoder = JSONDecoder()
        guard let data: Data = (space as? IaSpace)?.metaData?.data(using: .utf8) else { return }
        
        if let metaData = try? decoder.decode(InternetArchive.MetaData.self, from: data) {
            self.store.dispatch(.Loaded(metaData))
        }
    }
    
    // MARK: - Save License
    private func saveLicense(licenseURL:String?) {
        guard let space = self.space as? IaSpace else { return }
        
        space.license = licenseURL
        
        Db.writeConn?.asyncReadWrite { tx in
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)
            
            // update active projects for this space
            let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }
            
            for project in projects {
                project.license = space.license
                tx.setObject(project)
            }
        }
    }
    
    // MARK: - Remove Space
    private func remove() {
        Db.writeConn?.readWrite { tx in
            tx.removeObject(forKey: space.id, inCollection: Space.collection)
            
            // clear selected space
            SelectedSpace.space = nil
            SelectedSpace.store(tx)
            
            // select another space if available
            tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
                SelectedSpace.space = space
                stop = true
            }
            SelectedSpace.store(tx)
            
            self.store.notify(.Removed)
        }
    }
}

// MARK: - License URL Helper
func generateLicenseURL(state: InternetArchiveDetailState) -> String? {
    guard state.isCcEnabled else { return nil }
    
    // If CC0 is enabled, return CC0 URL
    if state.isCc0Enabled {
        return "https://creativecommons.org/publicdomain/zero/1.0/"
    }
    
    // Regular CC license
    var license = "by"
    
    if state.allowRemix {
        if !state.allowCommercialUse { license += "-nc" }
        if state.requireShareAlike { license += "-sa" }
    } else {
        if !state.allowCommercialUse { license += "-nc" }
        license += "-nd"
    }
    
    return "https://creativecommons.org/licenses/\(license)/4.0/"
}

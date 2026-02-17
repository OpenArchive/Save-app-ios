
import Combine
import Foundation

extension Notification.Name {
    static let spaceUpdated = Notification.Name("spaceUpdated")
}

struct ServerSettingsState {
    var space: Space?
    var serverName: String = ""
    var serverURL: String = ""
    var username: String = ""
    var password: String = "••••••••"
    
    // Creative Commons License Toggles
    var isCcEnabled: Bool = false
    var isCc0Enabled: Bool = false
    var allowRemix: Bool = false
    var requireShareAlike: Bool = false
    var allowCommercialUse: Bool = false
    var licenseURL: String? = nil
}

enum ServerSettingsAction {
    case updateServerName(String)
    case updateServerURL(String)
    
    case toggleCcEnabled(Bool)
    case toggleCc0Enabled(Bool)
    case toggleAllowRemix(Bool)
    case toggleRequireShareAlike(Bool)
    case toggleAllowCommercialUse(Bool)
    case saveToDatabase
    case removeSpace(Space?)
    case updateLicense
}

class ServerSettingsStore: ObservableObject {
    @Published private(set) var state: ServerSettingsState
    
    init(initialState: ServerSettingsState) {
        self.state = initialState
    }
    
    func dispatch(action: ServerSettingsAction) {
        serverSettingsReducer(state: &state, action: action)
        if case .updateLicense = action {
            objectWillChange.send()
        }
    }
    
    deinit {
    }
}

func serverSettingsReducer(state: inout ServerSettingsState, action: ServerSettingsAction) {
    switch action {
    case .updateServerName(let name):
        state.serverName = name
        
    case .updateServerURL(let url):
        state.serverURL = url
        
    case .toggleCcEnabled(let isEnabled):
            state.isCcEnabled = isEnabled
            if !isEnabled {
                state.isCc0Enabled = false
                state.allowRemix = false
                state.requireShareAlike = false
                state.allowCommercialUse = false
            }
            
        case .toggleCc0Enabled(let isEnabled):
            state.isCc0Enabled = isEnabled
            if isEnabled {
           
                state.allowRemix = false
                state.requireShareAlike = false
                state.allowCommercialUse = false
            }
            
        case .toggleAllowRemix(let value):
            state.allowRemix = value
            if !value { state.requireShareAlike = false }
         
            if value { state.isCc0Enabled = false }
            
        case .toggleRequireShareAlike(let value):
            state.requireShareAlike = value
          
            if value { state.isCc0Enabled = false }
            
        case .toggleAllowCommercialUse(let value):
            state.allowCommercialUse = value
          
            if value { state.isCc0Enabled = false }
            
        case .updateLicense:
        state.licenseURL = generateLicenseURL(state: state)
        saveLicenseToDatabase(state: state)
    case .saveToDatabase:
        saveSpaceToDatabase(state: state)
    case .removeSpace(let value):
        removeSpace(space: value)
    }
    
    
}

func saveLicenseToDatabase(state: ServerSettingsState) {
    guard let space = state.space else { return }
    space.license = state.licenseURL

    Db.writeConn?.asyncReadWrite { tx in
        guard tx.hasObject(forKey: space.id, inCollection: Space.collection) else { return }
        tx.setObject(space, forKey: space.id, inCollection: Space.collection)
        
        let projects: [Project] = tx.findAll { $0.active && $0.spaceId == space.id }
        
        for project in projects {
            project.license = space.license
            tx.setObject(project)
        }
    }
}

func removeSpace(space:Space?){
    guard let id = space?.id else {
        return
    }
    Db.writeConn?.asyncReadWrite { tx in
        tx.removeObject(forKey: id, inCollection: Space.collection)
        
        SelectedSpace.space = nil
        SelectedSpace.store(tx)
        
        tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
            SelectedSpace.space = space
            stop = true
        }
        SelectedSpace.store(tx)
    }
}

func saveSpaceToDatabase(state: ServerSettingsState) {
    guard let space = state.space as? WebDavSpace else {
        return
    }

    space.name = state.serverName

    if let selectedSpace = SelectedSpace.space,
       selectedSpace.id == space.id {
        SelectedSpace.space = space
    }

    Db.writeConn?.asyncReadWrite({ tx in
        guard tx.hasObject(forKey: space.id, inCollection: Space.collection) else { return }
        tx.setObject(space, forKey: space.id, inCollection: Space.collection)
        SelectedSpace.store(tx)
    }, completionBlock: {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .spaceUpdated, object: space)
        }
    })
}

// Helper function to construct license URL
func generateLicenseURL(state: ServerSettingsState) -> String? {
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
    
    // Format the URL properly
    if #available(iOS 14.0, *) {
        return String(format: PrivateServerSettingsView.ccUrl, license)
    } else {
        return String(format: "https://creativecommons.org/licenses/%@/4.0/", license)
    }
}

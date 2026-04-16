
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

final class ServerSettingsStore: ObservableObject {

    @Published private(set) var state: ServerSettingsState

    init(initialState: ServerSettingsState) {
        self.state = initialState
    }

    func updateServerName(_ name: String) {
        state.serverName = name
    }

    func updateServerURL(_ url: String) {
        state.serverURL = url
    }

    func toggleCcEnabled(_ isEnabled: Bool) {
        state.isCcEnabled = isEnabled
        if !isEnabled {
            state.isCc0Enabled = false
            state.allowRemix = false
            state.requireShareAlike = false
            state.allowCommercialUse = false
        } else {
            updateLicense()
        }
    }

    func toggleCc0Enabled(_ isEnabled: Bool) {
        state.isCc0Enabled = isEnabled
        if isEnabled {
            state.allowRemix = false
            state.requireShareAlike = false
            state.allowCommercialUse = false
        }
        updateLicense()
    }

    func toggleAllowRemix(_ value: Bool) {
        state.allowRemix = value
        if !value { state.requireShareAlike = false }
        if value { state.isCc0Enabled = false }
        updateLicense()
    }

    func toggleRequireShareAlike(_ value: Bool) {
        state.requireShareAlike = value
        if value { state.isCc0Enabled = false }
        updateLicense()
    }

    func toggleAllowCommercialUse(_ value: Bool) {
        state.allowCommercialUse = value
        if value { state.isCc0Enabled = false }
        updateLicense()
    }

    func updateLicense() {
        state.licenseURL = generateLicenseURL(state: state)
        saveLicenseToDatabase(state: state)
        objectWillChange.send()
    }

    func saveToDatabase() {
        saveSpaceToDatabase(state: state)
    }

    func removeSpaceFromDatabase(_ space: Space?) {
        removeSpace(space: space)
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
    KeychainHelper.delete(key: "space.\(id).password")
    Db.writeConn?.asyncReadWrite({ tx in
        tx.removeObject(forKey: id, inCollection: Space.collection)

        SelectedSpace.space = nil
        SelectedSpace.store(tx)

        tx.iterateKeysAndObjects(inCollection: Space.collection) { (key, space: Space, stop) in
            SelectedSpace.space = space
            stop = true
        }
        SelectedSpace.store(tx)
    }, completionBlock: {
        // Notify that space was removed so MainView can refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .spaceUpdated, object: nil)
        }
    })
}

func saveSpaceToDatabase(state: ServerSettingsState) {
    guard let space = state.space as? WebDavSpace else {
        return
    }

    // Update the space object name
    space.name = state.serverName

    // Update SelectedSpace immediately in memory if it matches
    if let selectedSpace = SelectedSpace.space,
       selectedSpace.id == space.id {
        SelectedSpace.space = space
    }

    // Then save to database
    Db.writeConn?.asyncReadWrite({ tx in
        tx.setObject(space, forKey: space.id, inCollection: Space.collection)
        SelectedSpace.store(tx)
    }, completionBlock: {
        // Notify that space was updated so side menu can refresh
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

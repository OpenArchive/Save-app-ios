//
//  WebDavServer.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 21.09.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

class WebDavServer: Server {

    static let PRETTY_NAME = "WebDAV Server"
    private static let BASE_URL = "WEBDAV_BASE_URL"
    private static let SUBFOLDERS = "WEBDAV_SUBFOLDERS"
    private static let USERNAME = "WEBDAV_USERNAME"
    private static let PASSWORD = "WEBDAV_PASSWORD"

    static var baseUrl: String? {
        get {
            return UserDefaults(suiteName: Server.SUITE_NAME)?.string(forKey: WebDavServer.BASE_URL)
        }
        set {
            UserDefaults(suiteName: Server.SUITE_NAME)?.set(newValue, forKey: WebDavServer.BASE_URL)
        }
    }

    static var subfolders: String? {
        get {
            return UserDefaults(suiteName: Server.SUITE_NAME)?.string(forKey: WebDavServer.SUBFOLDERS)
        }
        set {
            UserDefaults(suiteName: Server.SUITE_NAME)?.set(newValue, forKey: WebDavServer.SUBFOLDERS)
        }
    }

    static var username: String? {
        get {
            return UserDefaults(suiteName: Server.SUITE_NAME)?.string(forKey: WebDavServer.USERNAME)
        }
        set {
            UserDefaults(suiteName: Server.SUITE_NAME)?.set(newValue, forKey: WebDavServer.USERNAME)
        }
    }

    static var password: String? {
        get {
            return UserDefaults(suiteName: Server.SUITE_NAME)?.string(forKey: WebDavServer.PASSWORD)
        }
        set {
            UserDefaults(suiteName: Server.SUITE_NAME)?.set(newValue, forKey: WebDavServer.PASSWORD)
        }
    }

    static var areCredentialsSet: Bool {
        get {
            return baseUrl != nil && !baseUrl!.isEmpty
                && username != nil && !username!.isEmpty
                && password != nil && !password!.isEmpty
        }
    }

    
    // MARK: Private Methods
    
    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `baseUrl` is a valid
     WebDAV URL.
     
     - returns: a `WebDAVFileProvider` with the provided `baseUrl` and stored credentials.
     */
    private lazy var provider: WebDAVFileProvider? = {
        if let username = WebDavServer.username,
            let password = WebDavServer.password,
            let baseUrl = publicUrl?.deletingLastPathComponent() {
            
            let credential = URLCredential(user: username, password: password, persistence: .forSession)
            
            return WebDAVFileProvider(baseURL: baseUrl, credential: credential)
        }
        
        return nil
    }()

    /**
     - returns: true, if this server is porperly configured.
    */
    static func isAvailable() -> Bool {
        if let baseUrl = WebDavServer.baseUrl,
            let username = WebDavServer.username,
            let password = WebDavServer.password {
            
            return !baseUrl.isEmpty && !username.isEmpty && !password.isEmpty
        }
        
        return false
    }
    
    /**
     Subclasses need to return a pretty name to show in the UI.

     - returns: A pretty name of this server.
     */
    override func getPrettyName() -> String {
        return WebDavServer.PRETTY_NAME
    }

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {
        
        if publicUrl == nil,
            var url = WebDavServer.baseUrl {
            
            // Should the file be stored in a/many subfolder(s)?
            if let subfolders = WebDavServer.subfolders {
                if !url.hasSuffix("/") && !subfolders.hasPrefix("/") {
                    url += "/"
                }
                
                url += subfolders
            }
            
            if !url.hasSuffix("/") {
                url += "/"
            }
            
            url += asset.filename

            publicUrl = URL(string: url)
        }

        if let filename = publicUrl?.lastPathComponent,
            let provider = provider,
            let file = asset.file {

            // Inject our own background session, so upload can finish, when
            // user quits app.
            // This can only be done on upload, we would get an error on
            // deletion.
            let conf = Server.sessionConf
            conf.urlCache = provider.cache
            conf.requestCachePolicy = .returnCacheDataElseLoad
            
            let sessionDelegate = SessionDelegate(fileProvider: provider)
            
            // Store for later re-set.
            let oldSession = provider.session
            
            provider.session = URLSession(configuration: conf,
                                          delegate: sessionDelegate as URLSessionDelegate?,
                                          delegateQueue: provider.operation_queue)
            
            var timer: DispatchSourceTimer?
            
            let prog = provider.copyItem(localFile: file, to: filename) { error in
                if let error = error {
                    self.publicUrl = nil
                    self.isUploaded = false
                    self.error = error.localizedDescription
                }
                else {
                    self.isUploaded = true
                    self.error = nil
                }
                
                timer?.cancel()
                
                // Reset to normal session, so #remove doesn't break.
                provider.session = oldSession
                
                DispatchQueue.main.async {
                    done(self)
                }
            }
            
            if let prog = prog {
                timer = DispatchSource.makeTimerSource(flags: .strict, queue: DispatchQueue.main)
                timer?.schedule(deadline: .now(), repeating: .seconds(1))
                timer?.setEventHandler() {
                    // For an uninvestigated reason, this progress counter runs until 200%, which looks
                    // kind of weird to the user, so we scale it down, here.
                    let scaledProgress = Progress(totalUnitCount: prog.totalUnitCount)
                    scaledProgress.completedUnitCount = prog.completedUnitCount / 2
                    
                    progress(self, scaledProgress)
                    
                    if scaledProgress.isCancelled {
                        prog.cancel()
                    }
                }
                timer?.resume()
            }
        }
    }

    override func remove(_ asset: Asset, done: @escaping DoneHandler) {
        if let filename = publicUrl?.lastPathComponent,
            let provider = provider {
            
            provider.removeItem(path: filename) { error in
                if let error = error {
                    self.error = error.localizedDescription
                }
                else {
                    self.publicUrl = nil
                    self.isUploaded = false
                    self.error = nil
                }

                DispatchQueue.main.async {
                    done(self)
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                self.error = nil

                done(self)
            }
        }
    }
}

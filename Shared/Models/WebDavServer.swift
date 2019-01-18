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

    private let config: ServerConfig?

    init(_ config: ServerConfig) {
        self.config = config

        if let id = config.url?.absoluteString {
            super.init(id)
        }
        else {
            super.init()
        }
    }

    required init(coder decoder: NSCoder) {
        config = decoder.decodeObject() as? ServerConfig

        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(config)

        super.encode(with: coder)
    }

    // MARK: Private Methods
    
    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `baseUrl` is a valid
     WebDAV URL.
     
     - returns: a `WebDAVFileProvider` with the provided `baseUrl` and stored credentials.
     */
    private var provider: WebDAVFileProvider? {
        if let username = config?.username,
            let password = config?.password,
            let baseUrl = publicUrl?.deletingLastPathComponent() {
            
            let credential = URLCredential(user: username, password: password, persistence: .forSession)
            
            return WebDAVFileProvider(baseURL: baseUrl, credential: credential)
        }
        
        return nil
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
        
        if publicUrl == nil {
            publicUrl = config?.url?.appendingPathComponent(asset.filename)
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

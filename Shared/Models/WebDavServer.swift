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

    private let space: Space?

    init(_ space: Space) {
        self.space = space

        super.init("webdav_with_space_\(space.id)")
    }

    required init(coder decoder: NSCoder) {
        space = decoder.decodeObject() as? Space

        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(space)

        super.encode(with: coder)
    }

    // MARK: Private Methods
    
    /**
     Subclasses need to return a pretty name to show in the UI.

     - returns: A pretty name of this server.
     */
    override func getPrettyName() -> String {
        return WebDavServer.PRETTY_NAME
    }

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {
        
        if asset.publicUrl == nil {
            asset.publicUrl = space?.url?.appendingPathComponent(asset.filename)
        }

        if let filename = asset.publicUrl?.lastPathComponent,
            let provider = space?.provider,
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
                    asset.publicUrl = nil
                    asset.isUploaded = false
                    asset.error = error.localizedDescription
                }
                else {
                    asset.isUploaded = true
                    asset.error = nil
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
        if let filename = asset.publicUrl?.lastPathComponent,
            let provider = space?.provider {
            
            provider.removeItem(path: filename) { error in
                if let error = error {
                    asset.error = error.localizedDescription
                }
                else {
                    asset.publicUrl = nil
                    asset.isUploaded = false
                    asset.error = nil
                }

                DispatchQueue.main.async {
                    done(self)
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                asset.error = nil

                done(self)
            }
        }
    }
}

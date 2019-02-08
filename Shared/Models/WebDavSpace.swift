//
//  WebDavSpace.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.02.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

/**
 A space supporting WebDAV servers such as Nextcloud/Owncloud.
 */
class WebDavSpace: Space, Item {

    // MARK: Item

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("WebDavSpace", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "WebDavSpace")
    }

    func compare(_ rhs: WebDavSpace) -> ComparisonResult {
        return super.compare(rhs)
    }


    // MARK: WebDavSpace

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `url` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` for this space.
     */
    var provider: WebDAVFileProvider? {
        if let username = username,
            let password = password,
            let baseUrl = url {

            let credential = URLCredential(user: username, password: password, persistence: .forSession)

            let provider = WebDAVFileProvider(baseURL: baseUrl, credential: credential)

            let conf = provider?.session.configuration ?? URLSessionConfiguration.default

            conf.sharedContainerIdentifier = Constants.appGroup
            conf.urlCache = provider?.cache
            conf.requestCachePolicy = .returnCacheDataElseLoad

            // Fix error "CredStore - performQuery - Error copying matching creds."
            conf.urlCredentialStorage = nil

            provider?.session = URLSession(configuration: conf,
                                           delegate: provider?.session.delegate,
                                           delegateQueue: provider?.session.delegateQueue)

            return provider
        }

        return nil
    }

    override init(_ name: String? = nil, _ url: URL? = nil, _ username: String? = nil, _ password: String? = nil) {
        super.init(name, url, username, password)
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    // MARK: Space

    override func upload(_ asset: Asset, progress: @escaping ProgressHandler,
                         done: @escaping DoneHandler) {

        if asset.publicUrl == nil {
            asset.publicUrl = url?.appendingPathComponent(asset.filename)
        }

        if let filename = asset.publicUrl?.lastPathComponent,
            let provider = provider,
            let file = asset.file {

            // Inject our own background session, so upload can finish, when
            // user quits app.
            // This can only be done on upload, we would get an error on
            // deletion.
            let conf = Space.sessionConf
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
                    done(asset)
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

                    progress(asset, scaledProgress)

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
            let provider = provider {

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
                    done(asset)
                }
            }
        }
        else {
            // If it's just not on the server, anyway, it's ok to call the success callback.
            if !asset.isUploaded {
                // Remove old errors, so the callback doesn't stumble over that.
                asset.error = nil

                done(asset)
            }
        }
    }
}

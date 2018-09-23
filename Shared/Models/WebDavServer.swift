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

    private static let PRETTY_NAME = "WebDAV Server"
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
            let baseUrl = WebDavServer.baseUrl,
            let subfolders = WebDavServer.subfolders {
            publicUrl = URL(string: "\(baseUrl)/\(subfolders)/\(asset.filename)")
        }

        if let url = publicUrl,
            let provider = getProvider(baseUrl: url.deletingLastPathComponent()),
            let file = asset.file {

            let prog = provider.copyItem(localFile: file, to: url.lastPathComponent) { error in
                if let error = error {
                    self.publicUrl = nil
                    self.isUploaded = false
                    self.error = error.localizedDescription
                }
                else {
                    self.isUploaded = true
                    self.error = nil
                }

                done(self)
            }

            if let prog = prog {
                progress(self, prog)
            }
        }
    }

    override func remove(_ asset: Asset, done: @escaping DoneHandler) {
        if let url = publicUrl,
            let provider = getProvider(baseUrl: url.deletingLastPathComponent()) {

            let file = url.lastPathComponent

            provider.removeItem(path: file) { error in
                if let error = error {
                    self.error = error.localizedDescription
                }
                else {
                    self.publicUrl = nil
                    self.isUploaded = false
                    self.error = nil
                }

                done(self)
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

    // MARK: Private Methods

    /**
     Create a `WebDAVFileProvider`, if credentials are available and the `baseUrl` is a valid
     WebDAV URL.

     - returns: a `WebDAVFileProvider` with the provided `baseUrl` and stored credentials.
    */
    private func getProvider(baseUrl: URL) -> WebDAVFileProvider? {
        if let username = WebDavServer.username,
            let password = WebDavServer.password {

            let credential = URLCredential(user: username, password: password, persistence: .permanent)

            return WebDAVFileProvider(baseURL: baseUrl, credential: credential)
        }

        return nil
    }
}

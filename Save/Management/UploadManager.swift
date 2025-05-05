//
//  UploadManager.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import Reachability
import Regex
import BackgroundTasks
import Photos
import TorManager
import StoreKit

extension Notification.Name {
    static let uploadManagerPause = Notification.Name("uploadManagerPause")
    
    static let uploadManagerUnpause = Notification.Name("uploadManagerUnpause")
    
    static let uploadManagerDone = Notification.Name("uploadManagerDone")
    
    static let uploadManagerDataUsageChange = Notification.Name("uploadManagerDataUsageChange")
}

extension AnyHashable {
    static let error = "error"
    static let url = "url"
}

/**
 Handles uploads in the background.
 
 Retry logic should work as follows:
 
 - Check every minute.
 - If no network connection - come back later.
 - If network connection, try upload.
 - If failed, increase retry counter of upload, wait with that upload for retry ^ 1.5 minutes (see [plot](http://fooplot.com/?lang=en#W3sidHlwZSI6MCwiZXEiOiJ4XjEuNSIsImNvbG9yIjoiIzAwMDAwMCJ9LHsidHlwZSI6MTAwMCwid2luZG93IjpbIjAiLCIxMSIsIjAiLCI0MCJdfV0-))
 - If retried 10 times, give up with that upload: set it paused. User can restart through unpausing.
 - Circuit breaker per space (to reduce load on server):
 - Count failed upload attempts.
 - If failed 10 times, wait 10 minutes before any other upload to that space is tried.
 - If one upload retry failed again, wait 10 minutes again before next upload is tried.
 - If one upload succeeded, reset space's fail count.
 
 User can pause and unpause a scheduled upload any time to reset counters and have a retry immediately.
 */
class UploadManager: NSObject, URLSessionTaskDelegate {
    
    static let shared = UploadManager()
    
    static var backgroundCompletionHandler: (() -> Void)?
    
    /**
     Maximum number of upload retries per upload item before giving up.
     */
    static let maxRetries = 10
    
    var waiting: Bool {
        globalPause || 
        (reachability?.connection ?? Reachability.Connection.unavailable == .unavailable) ||
        (Settings.useOrbot && OrbotManager.shared.status == .stopped) ||
        (Settings.useTor && !TorManager.shared.connected)
    }
    
    private var current: Upload?
    
    var reachability: Reachability? = {
        var reachability = try? Reachability()
        reachability?.allowsCellularConnection = !Settings.wifiOnly
        
        return reachability
    }()
    
    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(String(describing: UploadManager.self))")
    
    private var globalPause = false
    
    /**
     Polls tracked Progress objects and updates `Update` objects every second.
     */
    var progressTimer: DispatchSourceTimer?
    
    private var scheduler: Timer?
    
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    
    private var _backgroundSession: URLSession?
    private var _foregroundSession: URLSession?
    
    /**
     A session, which is enabled for background uploading.
     
     Only use this to upload the main file of an asset. All other usages will break, latest when the app goes into background!
     
     This needs to be tied to an object, otherwise the `URLSession` will get
     destroyed during the request and the request will break with error -999.
     */
    private var backgroundSession: URLSession {
        if _backgroundSession == nil {
            let conf = URLSessionConfiguration.background(withIdentifier:
                                                            "\(Bundle.main.bundleIdentifier ?? "").background")
            
            conf.isDiscretionary = false
            conf.shouldUseExtendedBackgroundIdleMode = true
            
            _backgroundSession = URLSession(
                configuration: Self.improvedSessionConf(conf),
                delegate: self, delegateQueue: nil)
        }
        
        return _backgroundSession!
    }
    
    /**
     A session wich is foreground-uploading only. This enables data
     chunks to get uploaded without the need for a file on disk.
     */
    private var foregroundSession: URLSession {
        if _foregroundSession == nil {
            _foregroundSession = URLSession(
                configuration: Self.improvedSessionConf(),
                delegate: self, delegateQueue: nil)
        }
        
        return _foregroundSession!
    }
    
    
    public class func improvedSessionConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        let conf = URLSessionConfiguration.improved(conf)
        
        if Settings.useTor {
            conf.connectionProxyDictionary = TorManager.shared.torSocks5ProxyConf
        }
        
        return conf
    }
    
    
    private override init() {
        super.init()
        
        // We were only initialized to handle the uploads which finished in the background.
        if Self.backgroundCompletionHandler != nil {
            // Trigger recreation of the background session, so it can handle
            // the finished uploads.
            _ = backgroundSession
        }
        else {
            restart()
        }
    }
    
    func reinitSession() {
        _backgroundSession = nil
        _foregroundSession = nil
    }
    
    /**
     (Re-)starts the `UploadManager`:
     
     - Reconnects all observers.
     - Restarts `Reachability` notifier.
     - Restarts `progressTimer`.
     - Re-initializes and starts #uploadNext scheduler.
     - Begins a new background task to keep app alive after user goes away.
     */
    func restart() {
        scheduler?.invalidate()
        progressTimer?.cancel()
        
        let nc = NotificationCenter.default
        
        nc.removeObserver(self)
        
        Db.add(observer: self, #selector(yapDatabaseModified))
        
        nc.addObserver(self, selector: #selector(done(_:)),
                       name: .uploadManagerDone, object: nil)
        
        nc.addObserver(self, selector: #selector(pause),
                       name: .uploadManagerPause, object: nil)
        
        nc.addObserver(self, selector: #selector(unpause),
                       name: .uploadManagerUnpause, object: nil)
        
        nc.addObserver(self, selector: #selector(reachabilityChanged),
                       name: .reachabilityChanged, object: reachability)
        
        nc.addObserver(self, selector: #selector(dataUsageChanged),
                       name: .uploadManagerDataUsageChange, object: nil)
        
        nc.addObserver(self, selector: #selector(orbotStopped),
                       name: .orbotStopped, object: nil)
        
        try? reachability?.startNotifier()
        
        progressTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        progressTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        progressTimer?.setEventHandler {
            if let upload = self.current,
               upload.hasProgressChanged() {
                
                self.debug("#progress tracker changed for \(upload))")
                
                // Update internal _progress to latest progress, so #hasProgressChanged
                // doesn't trigger anymore.
                self.current?.progress = upload.progress
                
                self.storeCurrent()
            }
        }
        
        progressTimer?.resume()
        
        scheduler = Timer(fireAt: Date().addingTimeInterval(5), interval: 10,
                          target: self, selector: #selector(uploadNext),
                          userInfo: nil, repeats: true)
        
        // Schedule a timer, which calls #uploadNext every 10 seconds beginning
        // in 5 seconds.
        RunLoop.main.add(scheduler!, forMode: .common)
    }
    
    
    // MARK: URLSessionTaskDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Self.backgroundCompletionHandler?()
    }
    
    /**
     This handles a finished file upload task, but ignores metadata files and file chunks.
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debug("#task:didCompleteWithError task=\(task), state=\(self.getTaskStateName(task.state)), url=\(task.originalRequest?.url?.absoluteString ?? "nil") error=\(String(describing: error))")
        
        // Ignore incomplete tasks. Ignore canceled tasks.
        guard task.state == .completed,
              let url = task.originalRequest?.url,
              (error as? NSError)?.code != -999 /* cancelled */
        else {
            return
        }
        
        let filename = url.lastPathComponent
        
        // Ignore Metadata files.
        for file in Asset.Files.allCases {
            if !file.isInternal && filename =~ "\(file.rawValue)$" {
                return
            }
        }
        
        guard task is URLSessionUploadTask && filename !~ "\\d{15}-\\d{15}" /* ignore chunks */ else {
            return
        }
        
        if current?.filename == filename {
            done(current?.id, error, url, synchronous: true)
        }
        else {
            if let found = Db.bgRwConn?.find(group: UploadsView.groups.first, in: UploadsView.name, where: { (tx, upload: inout Upload) in
                
                // Look at next, if it's paused or delayed.
                guard !upload.paused else {
                    return false
                }
                
                // First attach object chain to upload before next call,
                // otherwise, that will trigger more DB reads and with that
                // a deadlock.
                upload.preheat(tx)
                
                // Look at next, if it's not ready, yet.
                guard  upload.filename == filename && upload.isReady else {
                    return false
                }
                
                return true
            })
            {
                current = found // Otherwise next call will do nothing.
                done(found.id, error, url, synchronous: true)
            }
        }
    }
    
    
    // MARK: Observers
    
    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     
     - parameter notification: YapDatabaseModified` or `YapDatabaseModifiedExternally` notification.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        guard let current = current else {
            return
        }
        
        var found = false
        
        Db.bgRwConn?.read({ tx in
            if let upload: Upload = tx.object(for: current.id) {
                
                // First attach object chain to upload before next call,
                // otherwise, that will trigger another DB read.
                upload.preheat(tx)
                upload.liveProgress = current.liveProgress
                
                self.current = upload
                
                found = true
            }
        })
        
        // Our job got deleted!
        if !found {
            current.cancel()
            self.current = nil
        }
    }
    
    /**
     User pressed pause on an upload job or started editing the job list.
     
     - parameter notification: An `uploadManagerPause` notification.
     */
    @objc func pause(notification: Notification) {
        let id = notification.object as? String
        
        debug("#pause id=\(id ?? "globally")")
        
        queue.async {
            if let id = id {
                self.pause(id)
            }
            else {
                self.globalPause = true
                
            }
            
            self.uploadNext()
        }
    }
    
    /**
     User pressed unpause on an upload job or ended editing the job list.
     
     - parameter notification: An `uploadManagerUnpause` notification.
     */
    @objc func unpause(notification: Notification) {
        let id = notification.object as? String
        
        debug("#unpause id=\(id ?? "globally")")
        
        queue.async {
            if let id = id {
                self.pause(id, pause: false)
            }
            else {
                self.globalPause = false
            }
            
            self.uploadNext()
        }
    }
    
    /**
     Handles upload errors.
     
     Should  always be errors, since success is actually handled in `#taskCompletionHandler`.
     
     - parameter notification: An `uploadManagerDone` notification.
     */
    @objc func done(_ notification: Notification) {
        done(notification.object as? String,
             notification.userInfo?[.error] as? Error,
             notification.userInfo?[.url] as? URL)
    }
    
    /**
     Will record an upload error to the `current` upload job and handle automatic delayed retries for that
     job or will remove the job and record status accordingly to `Asset` and `Collection`.
     
     - parameter id: The upload ID. Should match `current`'s ID, otherwise will return silently.
     - parameter error: An eventual error that happened.
     - parameter url: The URL the file was saved to.
     */
    private func done(_ id: String?, _ error: Error?, _ url: URL? = nil, synchronous: Bool = false) {
        debug("#done")
        
        guard let id = id else {
            return endBackgroundTask(.failed)
        }
        
        debug("#done id=\(id), error=\(String(describing: error)), url=\(url?.absoluteString ?? "nil")")
        
        let work: () -> Void = {
            guard id == self.current?.id,
                  let upload = self.current,
                  let asset = upload.asset
            else {
                return self.endBackgroundTask(.failed)
            }
            
            let collection: Collection?
            let space = asset.space
            
            if error != nil || url == nil {
                asset.setUploaded(nil)
                
                upload.liveProgress = nil
                upload.progress = 0
                
                if !upload.paused && !self.globalPause {
                    // Circuit breaker pattern: Increase circuit breaker counter on error.
                    space?.tries += 1
                    space?.lastTry = Date()
                    
                    upload.tries += 1
                    // We stop retrying, if the server denies us, or as soon as we hit the maximum number of retries.
                    upload.paused = error is SaveError || UploadManager.maxRetries <= upload.tries
                    upload.lastTry = Date()
                    
                    upload.error = error?.friendlyMessage ?? (
                        url == nil ? NSLocalizedString("No URL provided.", comment: "")
                        : NSLocalizedString("Unknown error.", comment: ""))
                    
                    if upload.paused {
                        let filesize = upload.asset?.filesize
                        
                        let data: [String: String?] = [
                            "error": upload.error,
                            "filesize": filesize != nil ? String(filesize!) : nil,
                            "type": upload.asset?.uti.identifier,
                            "retries": String(upload.tries),
                            "network": self.reachability?.connection.description]
                    }
                }
                
                collection = nil
            }
            else {
                asset.setUploaded(url)
                
                // Circuit breaker pattern: Reset circuit breaker counter on success.
                space?.tries = 0
                space?.lastTry = nil
                
                collection = asset.collection
                collection?.setUploadedNow()
            }
            
            Db.writeConn?.readWrite { tx in
                tx.replace(upload)
                
                if let collection = collection {
                    tx.replace(collection)
                }
                
                if let space = space {
                    tx.replace(space, forKey: space.id, inCollection: Space.collection)
                }
                
                tx.replace(asset)
            }
            
            self.current = nil
            
            self.endBackgroundTask(asset.isUploaded ? .newData : .failed)
            
            self.uploadNext()
        }
        
        if synchronous {
            work()
        }
        else {
            queue.async(execute: work)
        }
    }
    
    /**
     User changed the WiFi-only flag.
     
     - parameter notification: An `uploadManagerDataUsageChange` notification.
     */
    @objc func dataUsageChanged(notification: Notification) {
        let wifiOnly = notification.object as? Bool ?? false
        
        debug("#dataUsageChanged wifiOnly=\(wifiOnly)")
        
        reachability?.allowsCellularConnection = !wifiOnly
        
        reachabilityChanged(notification: Notification(name: .reachabilityChanged))
    }
    
    /**
     Network status changed.
     */
    @objc func reachabilityChanged(notification: Notification) {
        debug("#reachabilityChanged connection=\(reachability?.connection ?? .unavailable)")
        
        if reachability?.connection ?? .unavailable != .unavailable {
            uploadNext()
        }
    }
    
    @objc func orbotStopped(notification: Notification) {
        debug("#orbotStopped")
        
        current?.cancel()
        
        storeCurrent()
        
        current = nil
    }
    
    @objc func uploadNext() {
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.current?.cancel()
                
                self?.endBackgroundTask(.failed)
            }
        }
        
        queue.async {
            self.debug("#uploadNext")
            
            self.cleanup()
            
            if self.globalPause {
                self.debug("#uploadNext globally paused")
                
                return self.endBackgroundTask(.noData)
            }
            
            if self.reachability?.connection ?? Reachability.Connection.unavailable == .unavailable {
                self.debug("#uploadNext no connection")
                
                return self.endBackgroundTask(.noData)
            }
            
            // Check if there's currently an item uploading which is not paused and not already uploaded.
            if !(self.current?.paused ?? true) && self.current?.state != .uploaded {
                self.debug("#uploadNext already one uploading")
                
                return self.endBackgroundTask(.noData)
            }
            
            if Settings.useOrbot && OrbotManager.shared.status == .stopped {
                self.debug("#uploadNext should use Orbot, but Orbot not started")
                
                return self.endBackgroundTask(.noData)
            }
            
            if Settings.useTor && !TorManager.shared.connected {
                self.debug("#uploadNext should use built-in Tor, but Tor not started")
                
                return self.endBackgroundTask(.noData)
            }
            
            guard let upload = self.getNext(),
                  let asset = upload.asset
            else {
                //                let sessionCount = UserDefaults.standard.integer(forKey: "uploadSessionCount")
                //                   let prompted = UserDefaults.standard.bool(forKey: "hasPromptedReview")
                //
                //                   if sessionCount >= 5 && !prompted {
                //                       DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                //                           SKStoreReviewController.requestReview()
                //                           UserDefaults.standard.set(true, forKey: "hasPromptedReview")
                //                       }
                //                   }
                self.debug("#uploadNext nothing to upload")
                
                return self.endBackgroundTask(.noData)
            }
            
            self.debug("#uploadNext try upload=\(upload)")
            
            let space = upload.asset?.space
            let name = space is WebDavSpace ? "WebDAV" : upload.asset?.space?.name
            
            upload.liveProgress = Conduit
                .get(for: asset, self.backgroundSession, self.foregroundSession)?
                .upload(uploadId: upload.id)
            
            upload.error = nil
            
            Db.writeConn?.readWrite { tx in
                if let collection = asset.collection,
                   collection.closed == nil
                {
                    collection.close()
                    
                    tx.replace(collection)
                }
                
                tx.replace(upload)
            }
        }
    }
    
    
    // MARK: Private Methods
    
    private func debug(_ text: String) {
#if DEBUG
        print("[\(String(describing: type(of: self)))] \(text)")
#endif
    }
    
    private func getTaskStateName(_ state: URLSessionTask.State) -> String {
        switch state {
        case .running:
            return "running"
        case .suspended:
            return "suspended"
        case .canceling:
            return "canceling"
        case .completed:
            return "completed"
        @unknown default:
            return String(state.rawValue)
        }
    }
    
    /**
     Fetches the next upload job from the database.
     
     Careful: Will overwrite a `current` if already there, so check before calling this!
     
     - returns: `current` for convenience or `nil` if none found.
     */
    private func getNext() -> Upload? {
        Db.bgRwConn?.readWrite { tx in
            var next: Upload? = nil
            
            next = tx.find(group: UploadsView.groups.first, in: UploadsView.name) { upload in
                // Look at next, if it's paused or delayed.
                guard !upload.paused
                        && upload.state != .uploaded
                        && upload.nextTry.compare(Date()) == .orderedAscending 
                else {
                    return false
                }
                
                // First attach object chain to upload before next calls,
                // otherwise, that will trigger more DB reads and with that
                // a deadlock.
                upload.preheat(tx)
                
                // Do not try uploading to Google Drive before the user is properly logged into Google.
                if upload.asset?.space is GdriveSpace && GdriveConduit.user == nil {
                    return false
                }
                
                
                guard upload.isReady else {
                    
                    if let asset = upload.asset, !asset.isImporting {
                        if let phAsset = asset.phAsset {
                            
                            queue.async {
                                let id = UIApplication.shared.beginBackgroundTask()
                                AssetFactory.load(from: phAsset, into: asset) { asset in
                                    UIApplication.shared.endBackgroundTask(id)
                                }
                            }
                        }
                        else if asset.file?.exists == true {
                            
                            queue.async {
                                let id = UIApplication.shared.beginBackgroundTask()
                                
                                //                                      asset.generateProof {
                                asset.update({ asset in
                                    asset.isReady = true
                                }) { updatedAsset in
                                    UIApplication.shared.endBackgroundTask(id)
                                }
                                //       }
                            }
                        }
                        else {
                            // Couldn’t load anything; cancel
                            upload.error = NSLocalizedString("Couldn't import item!", comment: "")
                            upload.cancel()
                            upload.paused = true
                            tx.replace(upload)
                        }
                    }
                    
                    return false
                }
                
                return true
            }
            
            current = next
        }
        
        return current
    }
    
    /**
     Pause/unpause an upload.
     
     If it's the current upload, the upload will be cancelled and removed from being current.
     
     If it's not the current upload, just the according database entry's `paused` flag will be updated.
     
     - parameter id: The upload ID.
     - parameter pause: `true` to pause, `false` to unpause. Defaults to `true`.
     */
    private func pause(_ id: String, pause: Bool = true) {
        
        // The current upload can only ever get paused, because there should
        // be no paused current upload. It gets cancelled and removed when paused.
        if let upload = current, upload.id == id {
            if pause {
                current?.cancel()
                current?.paused = true
                
                storeCurrent()
                
                current = nil
            }
        }
        else {
            Db.bgRwConn?.readWrite { tx in
                if let upload: Upload = tx.object(for: id) {
                    upload.preheat(tx)
                    
                    if pause {
                        upload.paused = true
                    }
                    else {
                        upload.paused = false
                        upload.error = nil
                        upload.tries = 0
                        upload.lastTry = nil
                        upload.progress = 0
                        
                        // Also reset circuit-breaker. Otherwise users will get confused.
                        if let space = upload.asset?.space {
                            space.tries = 0
                            space.lastTry = nil
                            
                            tx.replace(space, forKey: space.id, inCollection: Space.collection)
                        }
                    }
                    
                    tx.replace(upload)
                }
            }
        }
    }
    
    /**
     Store the current upload job to the database.
     
     Fails silently, when `current` is `nil`!
     */
    private func storeCurrent() {
        if let upload = current {
            Db.writeConn?.readWrite { tx in
                // Could be, that our cache is out of sync with the database,
                // due to background upload not triggering a `yapDatabaseModified` callback.
                // Don't write non-existing objects into it: use `replace` instead of `setObject`.
                tx.replace(upload)
            }
        }
    }
    
    private func endBackgroundTask(_ result: UIBackgroundFetchResult) {
        debug("#endBackgroundTask result=\(result)")
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    /**
     For unknown reasons, race conditions happen, where uploads finish but assets never get marked as uploaded.
     
     Also, finished `Upload`s are accrued over time which are not needed anymore.
     */
    private func cleanup() {
        debug("#cleanup")
        
        Db.writeConn?.readWrite { tx in
            // 1. Find all uploaded `Upload` objects. They need to be removed.
            for upload in tx.findAll(where: { $0.state == .uploaded }) as [Upload] {
                upload.preheat(tx, deep: false)
                
                // 2. Check, if corresponding `Asset` is properly marked as "uploaded".
                // If not, fix this.
                if let asset = upload.asset, !asset.isUploaded {
                    // Cannot recover destination URL here, but we need to set something,
                    // so asset is marked uploaded and original file is deleted.
                    // The URL is unused currently, anyway.
                    asset.setUploaded(URL(fileURLWithPath: "/"))
                    tx.replace(asset)
                }
                
                // 3. Finally remove the finished `Upload`.
                tx.remove(upload)
            }
        }
    }
}

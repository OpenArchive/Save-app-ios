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
import FilesProvider
import Alamofire
import Regex
import CleanInsightsSDK
import BackgroundTasks

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

    private let singleCompletionHandler: ((UIBackgroundFetchResult) -> Void)?

    private var scheduler: Timer?

    private var oldBackgroundTaskId = UIBackgroundTaskIdentifier.invalid
    private let useNewBackgroundTask: Bool

    private var _backgroundSession: URLSession?
    private var _foregroundSession: URLSession?

    /**
     A session, which is enabled for background uploading.

     This needs to be tied to an object, otherwise the `URLSession` will get
     destroyed during the request and the request will break with error -999.
     */
    private var backgroundSession: URLSession {
        if _backgroundSession == nil {
            let conf = URLSessionConfiguration.background(withIdentifier:
                "\(Bundle.main.bundleIdentifier ?? "").background")

            conf.isDiscretionary = false
            conf.shouldUseExtendedBackgroundIdleMode = true

            _backgroundSession = URLSession.withImprovedConf(configuration: conf, delegate: self)
        }

        return _backgroundSession!
    }

    /**
     A session wich is foreground-uploading only. This enables data
     chunks to get uploaded without the need for a file on disk.
    */
    private var foregroundSession: URLSession {
        if _foregroundSession == nil {
            _foregroundSession = URLSession.withImprovedConf(delegate: self)
        }

        return _foregroundSession!
    }


    init(useNewBackgroundTask: Bool = false, _ singleCompletionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        self.useNewBackgroundTask = useNewBackgroundTask

        self.singleCompletionHandler = singleCompletionHandler

        super.init()

        AppDelegateBase.scheduleBackgroundTask()

        if Constants.testBackgroundUpload && singleCompletionHandler == nil {
            debug("Foreground manager stopped due to background testing")

            return
        }

        restart()
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

#if canImport(Tor)
        nc.addObserver(self, selector: #selector(torUseChanged),
                       name: .torUseChanged, object: nil)

        nc.addObserver(self, selector: #selector(torUseChanged),
                       name: .torStarted, object: nil)
#endif

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


    // MARK: URLSessionDelegate

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Self.backgroundCompletionHandler?()
    }

    /**
     This handles a finished file upload task, but ignores metadata files and file chunks.
    */
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debug("#task:didCompleteWithError task=\(task), state=\(self.getTaskStateName(task.state)), url=\(task.originalRequest?.url?.absoluteString ?? "nil") error=\(String(describing: error))")

        // Ignore incomplete tasks.
        guard task.state == .completed,
            let url = task.originalRequest?.url else {
            return
        }

        let filename = url.lastPathComponent

        // Ignore Metadata files.
        guard filename.lowercased() !~ "\(WebDavConduit.metaFileExt)$" else {
            return
        }

        // Dropbox upload
        if String(describing: type(of: task)) == "__NSCFBackgroundUploadTask",
            let host = url.host?.lowercased(),
            host =~ "dropbox"
            && filename.lowercased() == "upload"
            && current?.asset?.space is DropboxSpace {

            // Reconstruct path part of upload URL to store as Asset#publicUrl.
            var path = [String]()

            if let projectName = self.current?.asset?.project?.name {
                path.append(projectName)
            }
            if let collectionName = self.current?.asset?.collection?.name {
                path.append(collectionName)
            }
            if self.current?.asset?.tags?.contains(Asset.flag) ?? false {
                path.append(Asset.flag)
            }
            if let filename = self.current?.asset?.filename {
                path.append(filename)
            }

            // Will show an error, when path couldn't be constructed.
            done(current?.id, nil, path.count > 2 ? Conduit.construct(path) : nil)
        }
        // WebDAV upload
        else if task is URLSessionUploadTask
            && filename !~ "\\d{15}-\\d{15}" // Ignore chunks
            && current?.filename == filename {

            done(current?.id, error, url)
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

        Db.bgRwConn?.read { transaction in
            let viewTransaction = transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction

            viewTransaction?.iterateKeysAndObjects(inGroup: UploadsView.groups[0])
            { collection, key, object, index, stop in
                if let upload = object as? Upload,
                    upload.id == current.id {

                    // First attach object chain to upload before next call,
                    // otherwise, that will trigger another DB read.
                    self.heatCache(transaction, upload)
                    upload.liveProgress = current.liveProgress

                    self.current = upload

                    found = true
                    stop = true
                }
            }
        }

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

                // We also need to stop the current upload. Otherwise we could
                // earn a race condition, where the upload gets finished, while
                // at the same time the user tries to reorder the uploads.
                // Then an assertion will kill the app, if two different
                // animations for a row will happen at the same time.
                self.current?.cancel()

                self.storeCurrent()

                self.current = nil
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
    private func done(_ id: String?, _ error: Error?, _ url: URL? = nil) {
        debug("#done")

        guard let id = id else {
            return endBackgroundTask(.failed)
        }

        debug("#done id=\(id), error=\(String(describing: error)), url=\(url?.absoluteString ?? "nil")")

        queue.async {
            guard id == self.current?.id,
                let upload = self.current,
                let asset = upload.asset else {
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
                    upload.paused = error is FileProviderHTTPError || UploadManager.maxRetries <= upload.tries
                    upload.lastTry = Date()

                    upload.error = error?.friendlyMessage ?? (
                        url == nil ? NSLocalizedString("No URL provided.", comment: "")
                            : NSLocalizedString("Unknown error.", comment: ""))

                    if upload.paused {
                        let filesize = upload.asset?.filesize

                        let data: [String: String?] = [
                            "error": upload.error,
                            "filesize": filesize != nil ? String(filesize!) : nil,
                            "type": upload.asset?.uti,
                            "retries": String(upload.tries),
                            "network": self.reachability?.connection.description]

                        if let json = try? JSONEncoder().encode(data) {
                            CleanInsights.shared.measure(
                                event: "upload", "upload_failed", forCampaign: "upload_fails",
                                name: String(data: json, encoding: .utf8))
                        }
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

            Db.writeConn?.readWrite { transaction in
                if asset.isUploaded {
                    transaction.removeObject(forKey: id, inCollection: Upload.collection)

                    transaction.replace(collection, forKey: collection!.id, inCollection: Collection.collection)
                }
                else {
                    transaction.replace(upload, forKey: id, inCollection: Upload.collection)
                }

                if let space = space {
                    transaction.replace(space, forKey: space.id, inCollection: Space.collection)
                }

                transaction.replace(asset, forKey: asset.id, inCollection: Asset.collection)
            }

            self.current = nil

            self.endBackgroundTask(asset.isUploaded ? .newData : .failed)

            // Only do next, if this is not a background upload.
            if self.singleCompletionHandler == nil {
                self.uploadNext()
            }
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

#if canImport(Tor)
    /**
     User changed Tor flag.

     - parameter notification: A `torUseChanged` notification.
     */
    @objc func torUseChanged(notification: Notification) {
        let useTor = notification.object as? Bool ?? Settings.useTor

        debug("#torUseChanged useTor=\(useTor)")

        backgroundSession = nil
        foregroundSession = nil
    }
#endif

    /**
     Network status changed.
     */
    @objc func reachabilityChanged(notification: Notification) {
        debug("#reachabilityChanged connection=\(reachability?.connection ?? .unavailable)")

        if reachability?.connection ?? .unavailable != .unavailable {
            uploadNext()
        }
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

            if self.globalPause {
                self.debug("#uploadNext globally paused")

                return self.endBackgroundTask(.noData)
            }

            if self.reachability?.connection ?? Reachability.Connection.unavailable == .unavailable {
                self.debug("#uploadNext no connection")

                return self.endBackgroundTask(.noData)
            }

            // Check if there's currently an item uploading which is not paused.
            if !(self.current?.paused ?? true) {
                self.debug("#uploadNext already one uploading")

                return self.endBackgroundTask(.noData)
            }

#if canImport(Tor)
            if Settings.useTor && !TorManager.shared.started {
                self.debug("#uploadNext should use Tor, but Tor not started")

                return self.endBackgroundTask(.noData)
            }
#endif

            guard let upload = self.getNext(),
                  let asset = upload.asset
            else {
                self.debug("#uploadNext nothing to upload")

                return self.endBackgroundTask(.noData)
            }

            self.debug("#uploadNext try upload=\(upload)")

            upload.liveProgress = Conduit
                .get(for: asset, self.backgroundSession, self.foregroundSession)?
                .upload(uploadId: upload.id)

            upload.error = nil

            Db.writeConn?.readWrite { transaction in
                if let collection = asset.collection,
                    collection.closed == nil {
                    
                    collection.close()

                    transaction.replace(collection, forKey: collection.id, inCollection: Collection.collection)
                }

                transaction.replace(upload, forKey: upload.id, inCollection: Upload.collection)
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
        Db.bgRwConn?.read { transaction in
            let viewTransaction = transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction

            var next: Upload? = nil

            viewTransaction?.iterateKeysAndObjects(inGroup: UploadsView.groups[0])
            { collection, key, object, index, stop in

                // Look at next, if it's paused or delayed.
                guard let upload = object as? Upload,
                    !upload.paused
                    && upload.nextTry.compare(Date()) == .orderedAscending else {
                    return
                }

                // First attach object chain to upload before next call,
                // otherwise, that will trigger more DB reads and with that
                // a deadlock.
                self.heatCache(transaction, upload)

                // Look at next, if it's not ready, yet.
                guard upload.isReady else {
                    return
                }

                next = upload
                stop = true
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
            Db.bgRwConn?.readWrite { transaction in
                if let upload = transaction.object(forKey: id, inCollection: Upload.collection) as? Upload {
                    self.heatCache(transaction, upload)

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

                            transaction.replace(space, forKey: space.id, inCollection: Space.collection)
                        }
                    }

                    transaction.replace(upload, forKey: id, inCollection: Upload.collection)
                }
            }
        }
    }

    /**
     Prefill the object chain to avoid deadlocking DB access when trying to access these objects.

     - parameter transaction: An active DB transaction
     - parameter upload: The object to heat up
     */
    private func heatCache(_ transaction: YapDatabaseReadTransaction, _ upload: Upload) {
        if let assetId = upload.assetId {
            upload.asset = transaction.object(forKey: assetId, inCollection: Asset.collection) as? Asset

            if let collectionId = upload.asset?.collectionId {
                upload.asset?.collection = transaction.object(
                    forKey: collectionId, inCollection: Collection.collection) as? Collection

                if let projectId = upload.asset?.collection?.projectId,
                    let project = transaction.object(forKey: projectId, inCollection: Project.collection) as? Project {

                    upload.asset?.collection?.project = project

                    if let spaceId = project.spaceId {
                        upload.asset?.collection?.project.space =
                            transaction.object(forKey: spaceId, inCollection: Space.collection) as? Space
                    }
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
            Db.writeConn?.readWrite { transaction in
                // Could be, that our cache is out of sync with the database,
                // due to background upload not triggering a `yapDatabaseModified` callback.
                // Don't write non-existing objects into it: use `replace` instead of `setObject`.
                transaction.replace(upload, forKey: upload.id, inCollection: Upload.collection)
            }
        }
    }

    private func endBackgroundTask(_ result: UIBackgroundFetchResult) {
        if backgroundTask != .invalid {
            if singleCompletionHandler != nil {
                debug("#endBackgroundTask - end background upload")
            }
            else {
                debug("#endBackgroundTask")
            }
        }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid

        guard let singleCompletionHandler = singleCompletionHandler else {
            return
        }

        scheduler?.invalidate()
        scheduler = nil

        reachability?.stopNotifier()

        progressTimer?.cancel()
        progressTimer = nil

        NotificationCenter.default.removeObserver(self)

        singleCompletionHandler(result)
    }
}

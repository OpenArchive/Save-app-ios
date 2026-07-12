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
import StoreKit

extension Notification.Name {
    static let uploadManagerPause = Notification.Name("uploadManagerPause")
    
    static let uploadManagerUnpause = Notification.Name("uploadManagerUnpause")
    
    static let uploadManagerDone = Notification.Name("uploadManagerDone")
    
    static let uploadManagerDataUsageChange = Notification.Name("uploadManagerDataUsageChange")

    /// Posted when upload state/progress changes and upload UI should refresh (grid + management queue).
    static let uploadGridRefresh = Notification.Name("uploadGridRefresh")
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

    /// True while iOS relaunched the app solely to deliver background URLSession events.
    private(set) static var isBackgroundSessionRelaunch = false

    /// Called from `AppDelegate` when iOS wakes the app for a background URLSession.
    static func prepareForBackgroundURLSession(completionHandler: @escaping () -> Void) {
        backgroundCompletionHandler = completionHandler
        isBackgroundSessionRelaunch = true
    }

    /// Called when the user opens the app — clears silent background-session wake state.
    static func noteUserForegrounded() {
        isBackgroundSessionRelaunch = false
    }

    /// Skip main-thread grid refreshes while backgrounded or during a background-session wake.
    var shouldDeferUIRefresh: Bool {
        isInBackground || Self.isBackgroundSessionRelaunch
    }

    private static let uploadQueueKey = DispatchSpecificKey<Void>()
    
    /**
     Maximum number of upload retries per upload item before giving up.
     */
    static let maxRetries = 10
    
    var waiting: Bool {
        globalPause || isBlockedByConnectivity
    }

    var isBlockedByConnectivity: Bool {
        connectivityBlockMessage != nil
    }

    /// User-facing message when uploads cannot proceed due to network settings.
    var connectivityBlockMessage: String? {
        let connection = reachability?.connection ?? .unavailable
        if connection == .unavailable {
            return UploadQueuePolicy.noNetworkMessage
        }
        if Settings.wifiOnly && connection == .cellular && !Settings.cellularOverride {
            return UploadQueuePolicy.wifiRequiredMessage
        }
        return nil
    }
    
    private var current: Upload?

    // Upload session tracking
    private var sessionUploadCount = 0
    private var sessionStartTime: Date?
    private var sessionTotalSize: Int64 = 0

    var reachability: Reachability? = {
        var reachability = try? Reachability()
        reachability?.allowsCellularConnection = !Settings.wifiOnly || Settings.cellularOverride

        return reachability
    }()

    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(String(describing: UploadManager.self))")

    private let backgroundStateLock = NSLock()
    private var _isInBackground = false
    private(set) var isInBackground: Bool {
        get {
            backgroundStateLock.lock()
            defer { backgroundStateLock.unlock() }
            return _isInBackground
        }
        set {
            backgroundStateLock.lock()
            _isInBackground = newValue
            backgroundStateLock.unlock()
        }
    }
    private var manualRetryId: String?

    /// Upload IDs with a started transfer still in flight (including background URLSession tasks).
    private var inFlightUploadIds = Set<String>()
    
    private var globalPause = false
    
    /**
     Polls tracked Progress objects and updates `Update` objects every second.
     */
    var progressTimer: DispatchSourceTimer?

    /// Tracks when the current upload last made progress, for timeout detection.
    private var lastProgressDate: Date?

    /// Throttles PROPFIND checks while waiting near 100% for the HTTP response.
    private var lastHighProgressServerCheckDate: Date?

    /// Throttle Yap progress writes to reduce UI/memory churn during long uploads.
    private var lastProgressStoreDate: Date?
    private var lastStoredProgress: Double = 0

    /// How long an upload can be stuck without progress before timing out.
    private static let uploadTimeoutInterval: TimeInterval = 60

    private var scheduler: Timer?
    
    private var isPollingSuspended = false
    
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    /// Keeps the app runnable while foreground prep (mkdir, metadata) finishes after backgrounding.
    private var inFlightBackgroundTask = UIBackgroundTaskIdentifier.invalid

    /// Upload IDs whose file bytes are on a background `URLSession` (safe to suspend the app).
    private var backgroundTransferStartedIds = Set<String>()
    
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
    
    
    /// Session config used for uploads and WebDAV operations (e.g. browse folders).
    public class func improvedSessionConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        return URLSessionConfiguration.improved(conf)
    }
    
    
    private override init() {
        super.init()

        queue.setSpecific(key: Self.uploadQueueKey, value: ())

        IaCooldownManager.shared.configure(onWake: { [weak self] in
            self?.queue.async {
                self?.ensurePollingActive()
                self?.uploadNext()
            }
        }, onCooldownStarted: { [weak self] in
            self?.syncIaUploadsForCooldownIfNeeded()
        }, queue: queue)

        // Recreate the background session when iOS relaunches us for finished uploads.
        let wakingForBackgroundSession = Self.backgroundCompletionHandler != nil
        if wakingForBackgroundSession {
            _ = backgroundSession
        }

        restart(skipInitialUploadNext: wakingForBackgroundSession)
    }
    
    func reinitSession() {
        _backgroundSession = nil
        _foregroundSession = nil
        WebDavConduit.clearFolderCache()
    }
    
    /**
     (Re-)starts the `UploadManager`:
     
     - Reconnects all observers.
     - Restarts `Reachability` notifier.
     - Restarts `progressTimer`.
     - Re-initializes and starts #uploadNext scheduler.
     - Begins a new background task to keep app alive after user goes away.
     */
    func restart(skipInitialUploadNext: Bool = false) {
        scheduler?.invalidate()
        progressTimer?.cancel()

        // Eagerly create the background session so uploads can hand off before suspension.
        _ = backgroundSession
        
        let nc = NotificationCenter.default
        
        nc.removeObserver(self)
        
        Db.add(observer: self, #selector(yapDatabaseModified))
        
        nc.addObserver(self, selector: #selector(done(_:)),
                       name: .uploadManagerDone, object: nil)
        
        nc.addObserver(self, selector: #selector(pause),
                       name: .uploadManagerPause, object: nil)
        
        nc.addObserver(self, selector: #selector(unpause),
                       name: .uploadManagerUnpause, object: nil)

        nc.addObserver(self, selector: #selector(uploadItemRemoved(_:)),
                       name: .uploadItemRemoved, object: nil)
        
        nc.addObserver(self, selector: #selector(reachabilityChanged),
                       name: .reachabilityChanged, object: reachability)
        
        nc.addObserver(self, selector: #selector(dataUsageChanged),
                       name: .uploadManagerDataUsageChange, object: nil)
        
        try? reachability?.startNotifier()

        isPollingSuspended = true

        Db.writeConn?.readWrite { tx in
            UploadQueueService.resetDeferredLargeFlags(tx: tx)
        }

        syncIaUploadsForCooldownIfNeeded()

        if IaCooldownManager.shared.isActive {
            current?.cancel()
            current = nil
            lastProgressDate = nil
        }

        if !skipInitialUploadNext {
            uploadNext()
        }
    }

    /// Called from `sceneWillResignActive` — begin extra runtime before iOS suspends the process.
    func prepareForPossibleBackground() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.prepareForPossibleBackground() }
            return
        }
        guard UploadMemoryLog.pendingUploadCount() > 0 else { return }
        queue.sync {
            self.prepareWebDavFoldersIfNeeded()
        }
        beginInFlightBackgroundTaskSynchronously()
    }

    /// Called synchronously from `sceneDidEnterBackground` on the main thread.
    func willEnterBackground() {
        isInBackground = true
        logUploadMemory("app_background")
        if UploadMemoryLog.pendingUploadCount() > 0 {
            beginInFlightBackgroundTaskSynchronously()
        }
        reconcileInFlightBackgroundTasks()
        queue.async {
            self.handleEnterBackgroundOnQueue()
        }
    }

    /// Call after new uploads are written to the database (e.g. from Preview).
    func notifyUploadsEnqueued() {
        queue.async {
            // A newly enqueued batch should try cleanly — don't inherit a leftover IA 503 timer.
            if self.hasNormalPendingIaUploads() {
                IaCooldownManager.shared.reset(on: self.queue, reason: "new_batch_enqueued")
            }
            self.prepareWebDavFoldersIfNeeded()
            self.logUploadMemory("enqueued")
            self.ensurePollingActive()
            self.uploadNext()
        }
    }
    
    func setBackgroundState(_ inBackground: Bool) {
        isInBackground = inBackground
    }

    private func handleEnterBackgroundOnQueue() {
        if let upload = self.current, UploadQueueService.isLargeNextcloud(upload) {
            upload.cancel()
            upload.liveProgress = nil
            upload.progress = 0
            upload.deferredLargeThisBackground = true

            Db.writeConn?.readWrite { tx in
                UploadQueueService.moveToEnd(of: .normal, upload: upload, tx: tx)
            }

            self.current = nil
            self.lastProgressDate = nil
            self.clearInFlight(upload.id)
            self.uploadNext()
            return
        }

        self.suspendPollingIfIdle()
    }

    func resetDeferredLargeFlags() {
        queue.async {
            Db.writeConn?.readWrite { tx in
                UploadQueueService.resetDeferredLargeFlags(tx: tx)
            }
        }
    }

    func becameActive() {
        isInBackground = false
        queue.async {
            self.scrubStaleInFlightIds()
            self.reconcileInFlightBackgroundTasks()
            self.logUploadMemory("app_foreground")

            if let id = self.current?.id,
               self.backgroundTransferStartedIds.contains(id) {
                self.lastProgressDate = Date()
            }

            Db.writeConn?.readWrite { tx in
                UploadQueueService.resetDeferredLargeFlags(tx: tx)
            }
            self.syncIaUploadsForCooldownIfNeeded()
            if IaCooldownManager.shared.isActive {
                if let id = self.current?.id {
                    self.clearInFlight(id)
                }
                self.current?.cancel()
                self.current = nil
                self.lastProgressDate = nil
            }
            if !Self.isBackgroundSessionRelaunch {
                self.cleanup()
            }
            self.storeCurrent(force: true)

            let missedCooldownWake = IaCooldownManager.shared.shouldWakeForExpiredCooldown(
                pendingIa503: self.hasPendingIa503Retry()
            )
            if missedCooldownWake {
                IaCooldownLog.log(
                    "cooldown_expired",
                    pendingIa503: self.pendingIa503Count(),
                    reason: "foreground"
                )
            }

            if missedCooldownWake || self.hasActiveCurrentUpload() || self.hasRunnableUploadWork() {
                self.ensurePollingActive()
                self.uploadNext()
            } else {
                self.suspendPollingIfIdle()
            }
        }
    }
    
    
    // MARK: URLSessionTaskDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = Self.backgroundCompletionHandler
        Self.backgroundCompletionHandler = nil
        // Two hops on the upload queue:
        // 1) Run after any `didComplete` already queued (FIFO).
        // 2) Run again after a `didComplete` that iOS may have delivered *after* this
        //    callback — so the next file’s background PUT is enqueued before we tell
        //    iOS we’re done (otherwise batches stop after a few files).
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { handler?() }
                return
            }
            self.storeCurrent(force: true)
            self.ensurePollingActive()
            self.uploadNext()

            self.queue.async {
                self.uploadNext()

                if let id = self.current?.id, !self.hasBytesTransferStarted(id) {
                    self.beginInFlightBackgroundTaskSynchronously()
                }

                Self.isBackgroundSessionRelaunch = false
                DispatchQueue.main.async {
                    handler?()
                }
            }
        }
    }
    
    /**
     This handles a finished file upload task, but ignores metadata files and file chunks.
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let httpStatus = (task.response as? HTTPURLResponse)?.statusCode ?? -1
        let taskFile = task.originalRequest?.url?.lastPathComponent ?? "nil"
#if DEBUG
        print("[UploadDiag] didComplete taskId=\(task.taskIdentifier) file=\(taskFile) HTTP=\(httpStatus) state=\(getTaskStateName(task.state)) error=\(String(describing: error))")
#endif
        debug("#task:didCompleteWithError task=\(task), state=\(self.getTaskStateName(task.state)), url=\(task.originalRequest?.url?.absoluteString ?? "nil") error=\(String(describing: error))")

        // Clean up temp file if it exists (plain path, or "kind|id|path" encodings).
        if let description = task.taskDescription, !description.isEmpty {
            let parts = description.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            let tempFilePath = parts.count == 3 ? String(parts[2]) : description
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempFilePath))
        }

        queue.async { [weak self] in
            self?.handleBackgroundUploadTaskCompleted(task, error: error)
        }
    }

    /// Shared completion handler for URLSession delegate callbacks and lifecycle reconciliation.
    private func handleBackgroundUploadTaskCompleted(_ task: URLSessionTask, error: Error?) {
        guard task.state == .completed,
              let url = task.originalRequest?.url,
              (error as? NSError)?.code != -999 /* cancelled */
        else {
            return
        }

        let taskUrl = url.absoluteString
        let filename = url.lastPathComponent

        var effectiveError = error
        if effectiveError == nil,
           let httpResponse = task.response as? HTTPURLResponse,
           httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            effectiveError = SaveError.http(status: httpResponse.statusCode)
        }

        // Ignore metadata sidecar completions (WebDAV .meta.json / similar).
        if filename.hasSuffix(".meta.json") {
            return
        }

        for file in Asset.Files.allCases {
            if !file.isInternal && filename =~ "\(file.rawValue)$" {
                return
            }
        }

        guard task is URLSessionUploadTask && filename !~ "\\d{15}-\\d{15}" /* ignore chunks */ else {
            return
        }

        if let current, current.filename == filename {
            guard taskUrlMatchesUpload(url, upload: current) else {
                debug("didComplete ignored URL mismatch for current upload \(filename)")
                return
            }
            done(current.id, effectiveError, url)
        }
        else if let found = Db.bgRwConn?.find(group: UploadsView.groups.first, in: UploadsView.name, where: { (tx, upload: inout Upload) in

                guard !upload.paused else {
                    return false
                }

                upload.preheat(tx)

                guard upload.filename == filename && upload.isReady else {
                    return false
                }

                return true
            }),
            taskUrlMatchesUpload(url, upload: found)
        {
            current = found
            done(found.id, effectiveError, url)
        }
        else {
            debug("didComplete ignored orphan task file=\(filename) url=\(taskUrl)")
        }
    }
    
    
    // MARK: Observers
    
    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     
     - parameter notification: YapDatabaseModified` or `YapDatabaseModifiedExternally` notification.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        queue.async {
            self.handleYapDatabaseModifiedOnQueue()
        }
    }

    private func handleYapDatabaseModifiedOnQueue() {
        scrubStaleInFlightIds()

        guard let tracked = current else {
            return
        }

        var found = false

        Db.bgRwConn?.read({ tx in
            if let upload: Upload = tx.object(for: tracked.id) {
                upload.preheat(tx)
                upload.liveProgress = tracked.liveProgress
                self.current = upload
                found = true
            }
        })

        guard !found else { return }

        if let asset = tracked.asset {
            cancelBackgroundUploadTasksForAssetSync(asset, keepNewestDuplicate: false)
        }
        clearInFlight(tracked.id)
        tracked.cancel()
        tracked.trackCancellation(reason: "user_deleted")
        current = nil
        lastProgressDate = nil
        uploadNext()
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
    @objc func uploadItemRemoved(_ notification: Notification) {
        guard let upload = notification.object as? Upload else { return }
        cancelBackgroundUploadTasksForRemovedUpload(upload)
    }

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
            guard let upload = self.resolveUpload(for: id),
                  let asset = upload.asset
            else {
                return self.endBackgroundTask(.failed)
            }

            let space = asset.space
            let failureKind = error?.uploadFailureKind(for: space)

            if failureKind == .duplicateExists {
                let resolvedUrl = error?.duplicateSuccessURL(fallback: url) ?? url ?? asset.publicUrl
                self.current = upload
                self.handleUploadSuccess(upload: upload, asset: asset, url: resolvedUrl)
                return
            }

            if error == nil, url != nil, asset.isUploaded {
                self.clearInFlight(id)
                if self.current?.id == id {
                    self.current = nil
                    self.lastProgressDate = nil
                }
                Db.writeConn?.readWrite { tx in
                    tx.remove(upload)
                }
                self.notifyUploadGridRefresh()
                self.uploadNext()
                return self.endBackgroundTaskIfQueueIdle(.newData)
            }

            self.current = upload

            if error != nil || url == nil {
                if !asset.isUploaded {
                    self.handleUploadFailure(upload: upload, asset: asset, error: error)
                } else {
                    self.handleUploadSuccess(upload: upload, asset: asset, url: url ?? asset.publicUrl)
                }
            } else {
                self.handleUploadSuccess(upload: upload, asset: asset, url: url)
            }
        }
        
        if isOnUploadQueue {
            work()
        } else {
            queue.sync(execute: work)
        }
    }

    private func handleUploadSuccess(upload: Upload, asset: Asset, url: URL?) {
        let space = asset.space

        if let url = url {
            asset.setUploaded(url)
        }

        space?.tries = 0
        space?.lastTry = nil

        if space is IaSpace {
            // One IA success means the server is accepting work again —
            // clear the cooldown timer and auto-retry every parked 503 item.
            IaCooldownManager.shared.recordIaSuccess(on: queue)
            var unparked = 0
            Db.writeConn?.readWrite { tx in
                unparked = UploadQueueService.uploads(in: .ia503Retry, tx: tx).count
                UploadQueueService.demoteAllIa503ToNormal(tx: tx)
            }
            if unparked > 0 {
                IaCooldownLog.log(
                    "auto_retry_after_success",
                    pendingIa503: unparked,
                    reason: upload.filename
                )
            }
            notifyUploadGridRefresh()
        }

        upload.queueSection = .normal
        upload.autoRetryCount = 0
        upload.deferredLargeThisBackground = false
        upload.error = nil
        upload.freezeProgressForPersistence()
        upload.progress = 1.0

        let collection = asset.collection
        collection?.setUploadedNow()

        let backendType = space is WebDavSpace ? "WebDAV" : (space is IaSpace ? "Internet Archive" : nil)
        if let backendType = backendType, let startTime = upload.startTime {
            let duration = Date().timeIntervalSince(startTime)
            let fileType = AnalyticsEvent.mediaType(from: asset.file)
            let fileSizeKB = Int((asset.filesize ?? 0) / 1024)
            let uploadSpeedKbps = duration > 0 ? Double(fileSizeKB) / duration : 0

            trackEvent(.uploadCompleted(
                backendType: backendType,
                fileType: fileType,
                fileSizeKB: fileSizeKB,
                durationSeconds: duration,
                uploadSpeedKbps: uploadSpeedKbps
            ))

            SessionManager.shared.incrementUploadsCompleted()
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

        current = nil
        lastProgressDate = nil
        lastHighProgressServerCheckDate = nil
        manualRetryId = nil

        logUploadMemory("upload_success", upload: upload)

        notifyUploadGridRefresh()
        clearInFlight(upload.id)
        ensurePollingActive()

        uploadNext()
        endBackgroundTaskIfQueueIdle(.newData)
    }

    private func handleUploadFailure(upload: Upload, asset: Asset, error: Error?) {
        cancelBackgroundUploadTasksForAssetSync(asset, keepNewestDuplicate: false)
        cancelForegroundUploadTasksForFilenameSync(asset.filename)
        upload.cancel()
        if current?.id == upload.id {
            current = nil
            lastProgressDate = nil
        }
        upload.freezeProgressForPersistence()
        upload.progress = 0

        let space = asset.space
        let failureKind = error?.uploadFailureKind(for: space) ?? .other
        let failureMessage = message(for: error, kind: failureKind)

        #if DEBUG
        let httpStatus: String = {
            if let saveError = error as? SaveError, case .http(let status) = saveError {
                return String(status)
            }
            return "n/a"
        }()
        let backend = space is WebDavSpace ? "WebDAV" : (space is IaSpace ? "IA" : "unknown")
        print("[UploadDiag] upload_failure file=\(upload.filename) backend=\(backend) kind=\(failureKind) HTTP=\(httpStatus) parksQueue=\(failureKind == .ia503) error=\(error.map { String(describing: $0) } ?? "nil") message=\(failureMessage)")
        #endif

        asset.setUploaded(nil)

        switch failureKind {
        case .timeout, .serverError, .connectivity, .other:
            handleAutoRetryFailure(upload: upload, message: failureMessage)

        case .ia503:
            handleIa503Failure(upload: upload)

        case .duplicateExists:
            break
        }

        upload.freezeProgressForPersistence()

        Db.writeConn?.readWrite { tx in
            tx.replace(upload)
            tx.replace(asset)
        }

        if failureKind == .ia503 {
            syncIaUploadsForCooldownIfNeeded()
        }

        trackFailureIfNeeded(upload: upload, asset: asset, space: space, error: error)

        manualRetryId = nil

        logUploadMemory("upload_failure", upload: upload)

        notifyUploadGridRefresh()
        clearInFlight(upload.id)
        uploadNext()
        endBackgroundTaskIfQueueIdle(.failed)
    }

    private func message(for error: Error?, kind: UploadFailureKind) -> String {
        switch kind {
        case .connectivity:
            return connectivityBlockMessage ?? error?.friendlyMessage ?? UploadQueuePolicy.noNetworkMessage
        case .timeout:
            return error?.friendlyMessage ?? NSLocalizedString("Upload timed out.", comment: "")
        default:
            return error?.friendlyMessage ?? NSLocalizedString("Unknown error.", comment: "")
        }
    }

    private func handleAutoRetryFailure(upload: Upload, message: String) {
        upload.error = message

        if globalPause {
            Db.writeConn?.readWrite { tx in
                tx.replace(upload)
            }
            return
        }

        upload.autoRetryCount += 1
        upload.lastTry = nil
        upload.paused = upload.autoRetryCount > UploadQueuePolicy.maxAutoRetries

        Db.writeConn?.readWrite { tx in
            UploadQueueService.pushToEndOfQueue(upload, tx: tx)
            tx.replace(upload)
        }
    }

    /// IA 503: park all pending IA uploads, then cool down before retrying one.
    private func handleIa503Failure(upload: Upload) {
        upload.error = UploadQueuePolicy.iaBusyMessage
        upload.paused = false
        upload.progress = 0
        upload.queueSection = .ia503Retry
        upload.lastTry = nil

        Db.writeConn?.readWrite { tx in
            UploadQueueService.markAllPendingIa503(tx: tx)
            tx.replace(upload)
        }

        // Cooldown already running — park only; do not replace the single wake timer.
        if IaCooldownManager.shared.isActive {
            IaCooldownLog.log(
                "cooldown_already_active",
                minutes: IaCooldownManager.shared.scheduledMinutes,
                remainingSec: IaCooldownManager.shared.remainingSeconds,
                reason: "503_while_waiting"
            )
            return
        }

        // Post-wake retry still 503 — extend once and replace the (expired) timer.
        if IaCooldownManager.shared.hadExpiredCooldownBefore503() {
            IaCooldownLog.log("ia503", reason: "retry_still_503")
            IaCooldownManager.shared.onRetryFailedWith503(on: queue)
            return
        }

        IaCooldownLog.log("ia503", reason: "park_all")
        IaCooldownManager.shared.startCooldown(on: queue, reason: "ia503")
    }

    private func trackFailureIfNeeded(upload: Upload, asset: Asset, space: Space?, error: Error?) {
        // Track only when the upload stops auto-retrying (paused after max retries or other terminal state).
        guard upload.paused else {
            return
        }

        guard let backendType = space is WebDavSpace ? "WebDAV" : (space is IaSpace ? "Internet Archive" : nil) else {
            return
        }

        let fileType = AnalyticsEvent.mediaType(from: asset.file)
        let fileSizeKB = Int((asset.filesize ?? 0) / 1024)
        let errorCategory = error != nil ? "upload_error" : "no_url"
        trackEvent(.uploadFailed(
            backendType: backendType,
            fileType: fileType,
            errorCategory: errorCategory,
            fileSizeKB: fileSizeKB
        ))
        SessionManager.shared.incrementUploadsFailed()
    }
    
    /**
     User changed the WiFi-only flag.
     
     - parameter notification: An `uploadManagerDataUsageChange` notification.
     */
    @objc func dataUsageChanged(notification: Notification) {
        let wifiOnly = notification.object as? Bool ?? false
        
        debug("#dataUsageChanged wifiOnly=\(wifiOnly)")
        
        reachability?.allowsCellularConnection = !wifiOnly || Settings.cellularOverride
        
        reachabilityChanged(notification: Notification(name: .reachabilityChanged))
    }
    
    /**
     Network status changed.
     */
    @objc func reachabilityChanged(notification: Notification) {
        debug("#reachabilityChanged connection=\(reachability?.connection ?? .unavailable)")

        if !isBlockedByConnectivity && (hasRunnableUploadWork() || hasActiveCurrentUpload()) {
            uploadNext()
        }
    }
    
    @objc func uploadNext() {
        guard hasActiveCurrentUpload() || hasRunnableUploadWork() else {
            suspendPollingIfIdle()
            return
        }

        ensurePollingActive()

        let runWork = { self.runUploadNextWork() }

        guard isInBackground || Self.isBackgroundSessionRelaunch else {
            if isOnUploadQueue {
                runWork()
            } else {
                queue.async(execute: runWork)
            }
            return
        }

        beginBackgroundTaskIfNeeded {
            if self.isOnUploadQueue {
                runWork()
            } else if !Thread.isMainThread {
                self.queue.sync(execute: runWork)
            } else {
                self.queue.async(execute: runWork)
            }
        }
    }

    private var isOnUploadQueue: Bool {
        DispatchQueue.getSpecific(key: Self.uploadQueueKey) != nil
    }

    private func beginBackgroundTaskIfNeeded(then completion: @escaping () -> Void) {
        guard backgroundTask == .invalid else {
            completion()
            return
        }

        let begin = { [self] in
            guard backgroundTask == .invalid else {
                completion()
                return
            }
            var taskId: UIBackgroundTaskIdentifier = .invalid
            taskId = UIApplication.shared.beginBackgroundTask(withName: "UploadManager.uploadNext") { [weak self] in
                // Must end synchronously inside the expiration handler — async dispatch is too late.
                if taskId != .invalid {
                    UIApplication.shared.endBackgroundTask(taskId)
                    taskId = .invalid
                }
                guard let self else { return }
                if self.backgroundTask != .invalid {
                    self.backgroundTask = .invalid
                }
                self.queue.async {
                    guard let id = self.current?.id else {
                        self.uploadNext()
                        return
                    }
                    if self.hasBytesTransferStarted(id) {
                        return
                    }
                    self.clearInFlight(id)
                    self.current?.cancel()
                    self.current = nil
                    self.lastProgressDate = nil
                    self.uploadNext()
                }
            }
            backgroundTask = taskId
            completion()
        }

        // Never main.sync from the upload queue — except when backgrounded we must
        // begin the task synchronously or iOS suspends us before uploadNext runs.
        if Thread.isMainThread {
            begin()
        } else if isInBackground || Self.isBackgroundSessionRelaunch {
            DispatchQueue.main.sync(execute: begin)
        } else {
            DispatchQueue.main.async(execute: begin)
        }
    }

    /// End the uploadNext background task once the current file is on a background URLSession
    /// (or there is nothing left to prep). Do **not** hold the task for the whole remaining queue —
    /// iOS expires UIBackgroundTask in ~30s; the next wake comes from the background session.
    private func endBackgroundTaskIfQueueIdle(_ result: UIBackgroundFetchResult) {
        if isInBackground || Self.isBackgroundSessionRelaunch {
            if let id = current?.id, !hasBytesTransferStarted(id) {
                // Still in mkdir/meta prep — keep running until the BG PUT is enqueued.
                return
            }
        }
        endBackgroundTask(result)
    }

    private func runUploadNextWork() {
        debug("#uploadNext")

        if !isInBackground && !Self.isBackgroundSessionRelaunch {
            cleanup()
        }

        if globalPause {
            debug("#uploadNext globally paused")

            suspendPollingIfIdle()
            return endBackgroundTask(.noData)
        }

        if isBlockedByConnectivity {
            debug("#uploadNext blocked by connectivity")

            let reason = Settings.wifiOnly && reachability?.connection == .cellular
                ? "wifi_required" : "no_network"
            trackEvent(.uploadNetworkError(reason: reason))

            suspendPollingIfIdle()
            return endBackgroundTask(.noData)
        }

        // One upload at a time — inFlightUploadIds is set when a transfer starts.
        if hasActiveCurrentUpload() {
            debug("#uploadNext already one uploading")
            logInFlightDiagnostics("uploadNext blocked")
            reconcileInFlightBackgroundTasks()

            return endBackgroundTaskIfQueueIdle(.noData)
        }

        guard let upload = getNext(),
              let asset = upload.asset
        else {
            IaCooldownManager.shared.logBlockingIfNeeded(pendingIa503: pendingIa503Count())

            debug("#uploadNext nothing to upload")

            // Track upload session completion if one was in progress
            if sessionStartTime != nil {
                logUploadMemory("session_complete", extraStarted: sessionUploadCount)

                let duration = Date().timeIntervalSince(sessionStartTime!)
                let successCount = SessionManager.shared.sessionUploadsCompleted
                let failedCount = SessionManager.shared.sessionUploadsFailed
                let successRate = sessionUploadCount > 0 ? Double(successCount) / Double(sessionUploadCount) : 0

                trackEvent(.uploadSessionCompleted(
                    count: sessionUploadCount,
                    successCount: successCount,
                    failedCount: failedCount,
                    durationSeconds: duration,
                    successRate: successRate
                ))

                // Reset session tracking
                sessionStartTime = nil
                sessionUploadCount = 0
                sessionTotalSize = 0
            }

            suspendPollingIfIdle()
            return endBackgroundTask(.noData)
        }

        // Start upload session tracking if this is the first upload
        if sessionStartTime == nil {
            sessionStartTime = Date()
            sessionUploadCount = 0
            sessionTotalSize = 0
            SessionManager.shared.resetUploadCounters()
            logUploadMemory("session_start")
        }

        // Increment session counters
        sessionUploadCount += 1
        sessionTotalSize += asset.filesize ?? 0

        debug("#uploadNext try upload=\(upload)")
        if upload.queueSection == .ia503Retry {
            if !IaCooldownManager.shared.isActive {
                IaCooldownManager.shared.markWokenForCurrentExpiry()
            }
            IaCooldownLog.log(
                "cooldown_resumed_upload",
                pendingIa503: pendingIa503Count(),
                reason: upload.filename
            )
        }
        logUploadMemory("upload_start", upload: upload)

        let space = upload.asset?.space

        // Track upload started
        upload.startTime = Date()
        let backendType = space is WebDavSpace ? "WebDAV" : (space is IaSpace ? "Internet Archive" : nil)
        if let backendType = backendType {
            let fileType = AnalyticsEvent.mediaType(from: asset.file)
            let fileSizeKB = Int((asset.filesize ?? 0) / 1024)
            let fileSizeCategory = AnalyticsEvent.fileSizeCategory(bytes: asset.filesize ?? 0)
            trackEvent(.uploadStarted(
                backendType: backendType,
                fileType: fileType,
                fileSizeKB: fileSizeKB,
                fileSizeCategory: fileSizeCategory
            ))
        }

        current = upload
        upload.error = nil

        upload.progress = 0
        markInFlight(upload.id)
        notifyUploadGridRefresh()
        lastProgressDate = Date()
        lastHighProgressServerCheckDate = nil
        lastStoredProgress = 0
        lastProgressStoreDate = nil

        if let webDav = space as? WebDavSpace, !isInBackground {
            WebDavConduit.prepareCollectionFolders(
                for: asset,
                session: foregroundSession,
                credential: webDav.credential
            )
        }

        Db.writeConn?.readWrite { tx in
            if let collection = asset.collection,
               collection.closed == nil
            {
                collection.close()

                tx.replace(collection)
            }

            tx.replace(upload)
        }

        // While backgrounded, Conduit MUST run inline on this queue so the background
        // URLSession PUT exists before we return / before iOS suspends. Fire-and-forget
        // on a global queue is lost after a few wake cycles — remaining files never start.
        let uploadId = upload.id
        let bgSession = backgroundSession
        let fgSession = foregroundSession
        let startConduit = { [weak self] in
            _ = Conduit.get(for: asset, bgSession, fgSession)?.upload(uploadId: uploadId)
            self?.queue.async {
                guard let self, self.current?.id == uploadId else { return }
                self.persistUploadProgressToGrid()
            }
        }

        if isInBackground || Self.isBackgroundSessionRelaunch {
            startConduit()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: startConduit)
            endBackgroundTask(.newData)
        }
    }
    
    
    // MARK: Private Methods
    
    private func shouldPersistProgress(_ progress: Double) -> Bool {
        if progress <= 0.11 || progress >= 1 {
            lastStoredProgress = progress
            lastProgressStoreDate = Date()
            return true
        }
        if abs(progress - lastStoredProgress) >= 0.05 {
            lastStoredProgress = progress
            lastProgressStoreDate = Date()
            return true
        }
        if let last = lastProgressStoreDate, Date().timeIntervalSince(last) >= 3 {
            lastStoredProgress = progress
            lastProgressStoreDate = Date()
            return true
        }
        return false
    }

    private func debug(_ text: String) {
#if DEBUG
        print("[\(String(describing: type(of: self)))] \(text)")
#endif
    }

    /// Logs in-flight upload state to diagnose stalls (e.g. stuck at 10% = prep done, bytes not moving).
    private func logInFlightDiagnostics(_ reason: String) {
#if DEBUG
        guard let upload = current else {
            print("[UploadDiag] \(reason) inFlightIds=\(inFlightUploadIds) current=nil")
            return
        }
        let onBgSession = backgroundTransferStartedIds.contains(upload.id)
        let stalledSec = lastProgressDate.map { Int(Date().timeIntervalSince($0)) } ?? -1
        print("[UploadDiag] \(reason) file=\(upload.filename) progress=\(String(format: "%.3f", upload.progress)) onBackgroundSession=\(onBgSession) inBackground=\(isInBackground) stalledSec=\(stalledSec) inFlightIds=\(inFlightUploadIds.count)")
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

    private func hasActiveCurrentUpload() -> Bool {
        !inFlightUploadIds.isEmpty
    }

    /// Ensures WebDAV folder hierarchy exists before the app backgrounds.
    /// Ensures WebDAV folder hierarchy exists before the app backgrounds.
    /// Prepares folders for every pending WebDAV upload so background chaining can skip mkdir.
    private func prepareWebDavFoldersIfNeeded() {
        guard !isInBackground, !Self.isBackgroundSessionRelaunch else { return }

        var prepared = Set<String>()
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, _: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }
                upload.preheat(tx)
                guard let asset = upload.asset,
                      let space = asset.space as? WebDavSpace,
                      !asset.isUploaded else {
                    return
                }
                let key = "\(asset.collection?.project.name ?? "")/\(asset.collection?.name ?? "")"
                guard prepared.insert(key).inserted else { return }

                WebDavConduit.prepareCollectionFolders(
                    for: asset,
                    session: self.foregroundSession,
                    credential: space.credential
                )
            }
        }
    }

    // MARK: - Background URLSession task lifecycle

    /// Cancels background PUT tasks when the user removes an upload from the queue.
    func cancelBackgroundUploadTasksForRemovedUpload(_ upload: Upload) {
        backgroundSession.getAllTasks { tasks in
            self.cancelBackgroundUploadTasks(
                tasks: tasks,
                filename: upload.filename,
                keepNewestDuplicate: false
            )
        }
    }

    private func scrubStaleInFlightIds() {
        guard !inFlightUploadIds.isEmpty else { return }

        var stale: [String] = []
        Db.bgRwConn?.read { tx in
            for id in inFlightUploadIds where tx.object(for: id) as Upload? == nil {
                stale.append(id)
            }
        }

        guard !stale.isEmpty else { return }

        for id in stale {
            clearInFlight(id)
        }

        if current == nil {
            uploadNext()
        }
    }

    private func isMainAssetBackgroundUploadTask(_ task: URLSessionTask) -> Bool {
        guard task is URLSessionUploadTask,
              let filename = task.originalRequest?.url?.lastPathComponent
        else {
            return false
        }

        if filename =~ "\\d{15}-\\d{15}" {
            return false
        }

        for file in Asset.Files.allCases where !file.isInternal {
            if filename =~ "\(file.rawValue)$" {
                return false
            }
        }

        return true
    }

    private func backgroundUploadTaskFilename(_ task: URLSessionUploadTask) -> String? {
        guard let name = task.originalRequest?.url?.lastPathComponent else { return nil }
        return name.removingPercentEncoding ?? name
    }

    private func backgroundUploadTaskMatchesAsset(_ task: URLSessionUploadTask, asset: Asset) -> Bool {
        guard let url = task.originalRequest?.url else { return false }

        let file = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard file == asset.filename else { return false }

        if asset.space is IaSpace {
            return true
        }

        guard let collectionName = asset.collection?.name else { return false }

        let path = url.path.removingPercentEncoding ?? url.path
        return path.contains(collectionName)
    }

    private func cancelBackgroundUploadTasksForFilenameSync(
        _ filename: String,
        keepNewestDuplicate: Bool
    ) {
        let sem = DispatchSemaphore(value: 0)
        backgroundSession.getAllTasks { tasks in
            self.cancelBackgroundUploadTasks(
                tasks: tasks,
                filename: filename,
                keepNewestDuplicate: keepNewestDuplicate
            )
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
    }

    private func cancelBackgroundUploadTasksForAssetSync(_ asset: Asset, keepNewestDuplicate: Bool) {
        cancelBackgroundUploadTasksForFilenameSync(asset.filename, keepNewestDuplicate: keepNewestDuplicate)
    }

    private func cancelBackgroundUploadTasks(
        tasks: [URLSessionTask],
        filename: String,
        keepNewestDuplicate: Bool
    ) {
        let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            isMainAssetBackgroundUploadTask(task) && backgroundUploadTaskFilename(task) == filename
        }

        let keepId = keepNewestDuplicate
            ? matching.map(\.taskIdentifier).max()
            : nil
        var cancelled = 0

        for task in matching where task.state != .completed && task.state != .canceling {
            if let keepId, task.taskIdentifier == keepId {
                continue
            }
            task.cancel()
            cancelled += 1
        }

#if DEBUG
        if cancelled > 0 {
            print("[UploadDiag] cancelled \(cancelled) background task(s) for \(filename) keepNewest=\(keepNewestDuplicate) keepId=\(keepId.map(String.init) ?? "nil")")
        }
#endif
    }

    /// Drops duplicate and orphan background PUTs so only the newest task for `keepingFilename` remains.
    private func pruneStaleBackgroundUploadTasks(tasks: [URLSessionTask], keepingFilename: String) {
        pruneOrphanBackgroundUploadTasks(tasks: tasks, keepingFilename: keepingFilename)

        let sameFile = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            isMainAssetBackgroundUploadTask(task) && backgroundUploadTaskFilename(task) == keepingFilename
        }

        let keepId = sameFile.map(\.taskIdentifier).max()
        var cancelled = 0

        for task in sameFile where task.state != .completed && task.state != .canceling {
            guard let keepId, task.taskIdentifier != keepId else { continue }
            task.cancel()
            cancelled += 1
        }

#if DEBUG
        if cancelled > 0 {
            print("[UploadDiag] pruned \(cancelled) duplicate background task(s) for \(keepingFilename) keepId=\(keepId.map(String.init) ?? "nil")")
        }
#endif
    }

    private func pruneOrphanBackgroundUploadTasks(tasks: [URLSessionTask], keepingFilename: String?) {
        var cancelled = 0

        for task in tasks {
            guard let uploadTask = task as? URLSessionUploadTask,
                  isMainAssetBackgroundUploadTask(task),
                  task.state != .completed && task.state != .canceling,
                  let name = backgroundUploadTaskFilename(uploadTask)
            else {
                continue
            }

            if let keepingFilename, name == keepingFilename {
                continue
            }

            task.cancel()
            cancelled += 1
        }

#if DEBUG
        if cancelled > 0 {
            let keep = keepingFilename ?? "none"
            print("[UploadDiag] pruned \(cancelled) orphan background task(s) keeping=\(keep)")
        }
#endif
    }

    /// Rejects stale background URLSession completions from prior upload batches.
    private func taskUrlMatchesUpload(_ url: URL, upload: Upload) -> Bool {
        guard let asset = upload.asset else { return false }

        if asset.space is IaSpace {
            return true
        }

        guard let collectionName = asset.collection?.name else { return false }

        let path = url.path.removingPercentEncoding ?? url.path
        let file = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard file == asset.filename else { return false }

        return path.contains(collectionName)
    }

    /// After foreground↔background transitions, URLSession may not deliver `didComplete` promptly.
    private func reconcileInFlightBackgroundTasks() {
        guard !inFlightUploadIds.isEmpty else { return }

        backgroundSession.getAllTasks { [weak self] bgTasks in
            guard let self else { return }
            self.queue.async {
                self.reconcileInFlightBackgroundTasksOnQueue(bgTasks)
            }
        }
    }

    private func reconcileInFlightBackgroundTasksOnQueue(_ tasks: [URLSessionTask]) {
        guard let upload = current, inFlightUploadIds.contains(upload.id) else {
#if DEBUG
            debug("#reconcile skip no current in-flight upload tasks=\(tasks.count)")
#endif
            return
        }

        let transferStarted = hasBytesTransferStarted(upload.id)
        if !transferStarted {
            reconcilePrepPhaseStall(upload: upload, tasks: tasks)
            return
        }

        pruneStaleBackgroundUploadTasks(tasks: tasks, keepingFilename: upload.filename)

        let filename = upload.filename
        let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            guard task.state != .canceling else { return false }
            guard backgroundUploadTaskFilename(task) == filename else { return false }
            guard let url = task.originalRequest?.url else { return false }
            return taskUrlMatchesUpload(url, upload: upload)
        }.sorted { $0.taskIdentifier > $1.taskIdentifier }

#if DEBUG
        let uploadTasks = tasks.compactMap { $0 as? URLSessionUploadTask }
        print("[UploadDiag] reconcile file=\(filename) progress=\(String(format: "%.3f", upload.progress)) matching=\(matching.count) bgUploadTasks=\(uploadTasks.count)")
        for task in uploadTasks.prefix(5) {
            let name = task.originalRequest?.url?.lastPathComponent ?? "?"
            print("[UploadDiag]   taskId=\(task.taskIdentifier) state=\(getTaskStateName(task.state)) file=\(name)")
        }
#endif

        if let task = matching.first {
            if task.state == .completed {
                debug("#reconcile delivering missed completion for \(filename)")
                handleBackgroundUploadTaskCompleted(task, error: nil)
            } else {
#if DEBUG
                print("[UploadDiag] reconcile waiting taskId=\(task.taskIdentifier) state=\(getTaskStateName(task.state)) file=\(filename)")
#endif
                reconcileHighProgressStall(upload: upload, task: task)
            }
            return
        }

        guard let lastProgress = lastProgressDate else { return }

        let stallInterval: TimeInterval = isInBackground ? 45 : 20
        guard Date().timeIntervalSince(lastProgress) > stallInterval else { return }

        if upload.progress <= 0.85 {
#if DEBUG
            print("[UploadDiag] reconcile no matching task progress=\(String(format: "%.3f", upload.progress)) stalled=\(Int(Date().timeIntervalSince(lastProgress)))s — resetting")
#endif
            debug("#reconcile no matching task at low progress for \(filename) — resetting for retry")
            resetStalledInFlightUpload(upload)
            return
        }

        debug("#reconcile no background task for in-flight \(filename) — resetting for retry")
        resetStalledInFlightUpload(upload)
    }

    /// Near ~95% the BG session has usually sent all bytes and is waiting on the HTTP response.
    /// Do **not** cancel that — our previous 30s reset caused cancel/restart loops (see logs).
    /// Only shortcut: if the file is already on the server, mark complete.
    private func reconcileHighProgressStall(upload: Upload, task: URLSessionTask) {
        guard upload.progress >= 0.85, let lastProgress = lastProgressDate else { return }
        guard task.state == .running || task.state == .suspended else { return }

        let stalled = Date().timeIntervalSince(lastProgress)
        // Wait for the server response; only probe existence after a meaningful pause.
        let checkAfter: TimeInterval = isInBackground ? 90 : 45
        guard stalled > checkAfter else { return }

        // Throttle PROPFIND — reconcile runs often while blocked.
        let now = Date()
        if let lastCheck = lastHighProgressServerCheckDate,
           now.timeIntervalSince(lastCheck) < 30 {
            return
        }
        lastHighProgressServerCheckDate = now

#if DEBUG
        print("[UploadDiag] reconcile high-progress wait file=\(upload.filename) progress=\(String(format: "%.3f", upload.progress)) stalledSec=\(Int(stalled)) — checking server, not cancelling")
#endif

        guard let url = task.originalRequest?.url,
              let asset = upload.asset,
              let expectedSize = asset.filesize,
              let space = asset.space as? WebDavSpace
        else {
            return
        }

        if fileExistsOnServer(url, expectedSize: expectedSize, credential: space.credential) {
#if DEBUG
            print("[UploadDiag] high-progress — file already on server, completing file=\(upload.filename)")
#endif
            done(upload.id, nil, url)
            return
        }

        // Still waiting on didComplete. Only give up after a very long hang (not a normal response delay).
        let giveUpAfter: TimeInterval = isInBackground ? 600 : 300
        guard stalled > giveUpAfter else { return }

#if DEBUG
        print("[UploadDiag] high-progress give-up after \(Int(stalled))s — resetting file=\(upload.filename)")
#endif
        debug("#reconcile high-progress give-up for \(upload.filename) — resetting for retry")
        resetStalledInFlightUpload(upload)
    }

    private func fileExistsOnServer(_ url: URL, expectedSize: Int64, credential: URLCredential?) -> Bool {
        var exists = false
        let group = DispatchGroup()
        group.enter()
        foregroundSession.info(url, credential: credential) { info, _ in
            exists = info.first.map { $0.size == expectedSize } ?? false
            group.leave()
        }
        _ = group.wait(timeout: .now() + 15)
        return exists
    }

    /// Prep finished but background PUT never enqueued (stuck before `notifyBackgroundTransferEnqueued`).
    private func reconcilePrepPhaseStall(upload: Upload, tasks: [URLSessionTask]) {
#if DEBUG
        print("[UploadDiag] reconcile prep-phase file=\(upload.filename) progress=\(String(format: "%.3f", upload.progress)) bgTasks=\(tasks.count) — background PUT not started yet")
#endif
        guard let lastProgress = lastProgressDate else { return }

        let stallInterval: TimeInterval = isInBackground ? 45 : 60
        guard Date().timeIntervalSince(lastProgress) > stallInterval else { return }

        debug("#reconcile prep-phase stall for \(upload.filename) — resetting for retry")
        resetStalledInFlightUpload(upload)
    }

    private func resetStalledInFlightUpload(_ upload: Upload) {
        let id = upload.id
        if let asset = upload.asset {
            cancelBackgroundUploadTasksForAssetSync(asset, keepNewestDuplicate: false)
        }
        upload.cancel()
        upload.liveProgress = nil
        upload.progress = 0
        clearInFlight(id)

        if current?.id == id {
            current = nil
            lastProgressDate = nil
            lastHighProgressServerCheckDate = nil
        }

        Db.writeConn?.readWrite { tx in
            tx.replace(upload)
        }

        notifyUploadGridRefresh()
        uploadNext()
    }

    /// Called from Conduit once the main file is handed to a background `URLSession`.
    func notifyBackgroundTransferEnqueued() {
        let work = { [weak self] in
            guard let self else { return }
            if let id = self.current?.id ?? self.inFlightUploadIds.first {
                self.backgroundTransferStartedIds.insert(id)
#if DEBUG
                let name = self.current?.filename ?? id
                print("[UploadDiag] backgroundTransferStarted file=\(name) id=\(id)")
#endif
            }
            self.endInFlightBackgroundTask()
            self.endBackgroundTaskIfQueueIdle(.newData)
        }
        // When Conduit runs on the upload queue (background path), mark immediately so
        // expiration handlers see bytes-started before we yield to iOS.
        if isOnUploadQueue {
            work()
        } else {
            queue.async(execute: work)
        }
    }

    /// True once the main file PUT is on the background session.
    private func hasBytesTransferStarted(_ uploadId: String) -> Bool {
        backgroundTransferStartedIds.contains(uploadId)
    }

    private func cancelForegroundUploadTasksForFilenameSync(_ filename: String) {
        let sem = DispatchSemaphore(value: 0)
        foregroundSession.getAllTasks { tasks in
            self.cancelForegroundUploadTasks(tasks: tasks, filename: filename)
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
    }

    private func cancelForegroundUploadTasks(tasks: [URLSessionTask], filename: String) {
        var cancelled = 0
        for task in tasks.compactMap({ $0 as? URLSessionUploadTask }) {
            guard isMainAssetBackgroundUploadTask(task),
                  backgroundUploadTaskFilename(task) == filename,
                  task.state != .completed && task.state != .canceling
            else {
                continue
            }
            task.cancel()
            cancelled += 1
        }
#if DEBUG
        if cancelled > 0 {
            print("[UploadDiag] cancelled \(cancelled) foreground task(s) for \(filename)")
        }
#endif
    }

    private func markInFlight(_ id: String) {
        inFlightUploadIds.insert(id)
        if isInBackground {
            beginInFlightBackgroundTaskSynchronously()
        }
    }

    private func clearInFlight(_ id: String) {
        inFlightUploadIds.remove(id)
        backgroundTransferStartedIds.remove(id)
        if inFlightUploadIds.isEmpty {
            endInFlightBackgroundTask()
        }
    }

    /// Must run on the main thread while the app is still active — async dispatch is too late after backgrounding.
    private func beginInFlightBackgroundTaskSynchronously() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.beginInFlightBackgroundTaskSynchronously() }
            return
        }
        guard inFlightBackgroundTask == .invalid else { return }

        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "UploadManager.inFlight") { [weak self] in
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
                taskId = .invalid
            }
            guard let self else { return }
            if self.inFlightBackgroundTask != .invalid {
                self.inFlightBackgroundTask = .invalid
            }
            self.queue.async {
                self.handleInFlightBackgroundTaskExpired()
            }
        }
        inFlightBackgroundTask = taskId
    }

    private func endInFlightBackgroundTask() {
        let end = { [weak self] in
            guard let self, self.inFlightBackgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.inFlightBackgroundTask)
            self.inFlightBackgroundTask = .invalid
        }

        if Thread.isMainThread {
            end()
        } else {
            DispatchQueue.main.async(execute: end)
        }
    }

    /// Foreground prep ran out of background time before a background URLSession task was created.
    private func handleInFlightBackgroundTaskExpired() {
        guard let upload = current, let id = current?.id else { return }

        if hasBytesTransferStarted(id) {
            return
        }

        debug("#inFlightBackgroundTask expired during prep for \(upload)")
        clearInFlight(id)
        upload.cancel()
        current = nil
        lastProgressDate = nil
        uploadNext()
    }

    private func resolveUpload(for id: String) -> Upload? {
        if current?.id == id {
            return current
        }

        var resolved: Upload?
        Db.bgRwConn?.read { tx in
            guard let upload: Upload = tx.object(for: id) else {
                return
            }
            upload.preheat(tx)
            resolved = upload
        }
        return resolved
    }

    private func hasRunnableUploadWork() -> Bool {
        let cooldownActive = IaCooldownManager.shared.isActive
        let retryId = manualRetryId
        var found = false
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, stop: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }

                if self.inFlightUploadIds.contains(upload.id) {
                    return
                }

                if upload.queueSection == .ia503Retry,
                   cooldownActive,
                   upload.id != retryId {
                    return
                }

                upload.preheat(tx)

                found = true
                stop = true
            }
        }
        return found
    }

    private func startProgressTimer() {
        progressTimer?.cancel()
        progressTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        progressTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        progressTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            if let upload = self.current, upload.error == nil, upload.hasProgressChanged() {
                self.debug("#progress tracker changed for \(upload))")
                self.current?.progress = upload.liveProgress?.fractionCompleted ?? upload.progress
                self.lastProgressDate = Date()
                if !self.isInBackground && !Self.isBackgroundSessionRelaunch,
                   self.current?.id == upload.id {
                    self.persistUploadProgressToGrid()
                    self.notifyUploadGridRefresh()
                }
            }

            if !self.isInBackground,
               let upload = self.current,
               let asset = upload.asset,
               !self.hasBytesTransferStarted(upload.id),
               let lastProgress = self.lastProgressDate,
               Date().timeIntervalSince(lastProgress) > Self.uploadTimeoutInterval {
                self.debug("#timeout detected for \(upload)")
                self.logInFlightDiagnostics("timeout prep-phase")
                upload.cancel()
                self.handleUploadFailure(upload: upload, asset: asset, error: UploadTimeoutError())
                return
            }

            if !self.hasActiveCurrentUpload(),
               IaCooldownManager.shared.shouldWakeForExpiredCooldown(
                pendingIa503: self.hasPendingIa503Retry()
            ) {
                IaCooldownLog.log(
                    "cooldown_expired",
                    pendingIa503: self.pendingIa503Count(),
                    reason: "poll"
                )
                self.ensurePollingActive()
                self.uploadNext()
            }
        }
        progressTimer?.resume()
    }

    private func startScheduler() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduler?.invalidate()
            self.scheduler = Timer(
                fireAt: Date().addingTimeInterval(5),
                interval: 10,
                target: self,
                selector: #selector(self.uploadNext),
                userInfo: nil,
                repeats: true
            )
            RunLoop.main.add(self.scheduler!, forMode: .common)
        }
    }

    private func ensurePollingActive() {
        guard isPollingSuspended else { return }
        isPollingSuspended = false
        debug("#ensurePollingActive")
        startProgressTimer()
        startScheduler()
    }

    private func suspendPolling() {
        guard !isPollingSuspended else { return }
        isPollingSuspended = true
        debug("#suspendPolling")
        progressTimer?.cancel()
        progressTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.scheduler?.invalidate()
            self?.scheduler = nil
        }
    }

    /// Stop periodic polling when there is no upload work — especially while backgrounded.
    private func suspendPollingIfIdle() {
        guard !hasActiveCurrentUpload() else { return }

        if !hasRunnableUploadWork() {
            if IaCooldownManager.shared.isActive, pendingIa503Count() > 0 {
                IaCooldownLog.log(
                    "polling_suspended",
                    minutes: IaCooldownManager.shared.scheduledMinutes,
                    remainingSec: IaCooldownManager.shared.remainingSeconds,
                    pendingIa503: pendingIa503Count(),
                    reason: "waiting_cooldown"
                )
            }
            logUploadMemory("polling_idle")
            suspendPolling()
            endBackgroundTaskIfQueueIdle(.noData)
            return
        }

        if isInBackground && (globalPause || isBlockedByConnectivity) {
            logUploadMemory("polling_idle")
            suspendPolling()
        }
    }

    private func logUploadMemory(_ event: String, upload: Upload? = nil, extraStarted: Int? = nil) {
        var context = UploadMemoryLog.Context()
        context.sessionStarted = extraStarted ?? sessionUploadCount
        context.sessionCompleted = SessionManager.shared.sessionUploadsCompleted
        context.sessionFailed = SessionManager.shared.sessionUploadsFailed
        context.pendingUploads = UploadMemoryLog.pendingUploadCount()
        context.inBackground = isInBackground
        if let upload {
            context.filename = upload.filename
            context.fileSizeKB = upload.asset?.filesize
            let space = upload.asset?.space
            if space is WebDavSpace {
                context.backend = "WebDAV"
            } else if space is IaSpace {
                context.backend = "IA"
            }
        }
        UploadMemoryLog.log(event, context)
    }
    
    /**
     Fetches the next upload job from the database.
     
     Careful: Will overwrite a `current` if already there, so check before calling this!
     
     - returns: `current` for convenience or `nil` if none found.
     */
    private func getNext() -> Upload? {
        let retryId = manualRetryId
        let background = isInBackground
        let cooldownActive = IaCooldownManager.shared.isActive

        Db.bgRwConn?.readWrite { tx in
            current = UploadQueueService.selectNext(
                tx: tx,
                isInBackground: background,
                manualRetryId: retryId,
                iaCooldownActive: cooldownActive,
                inFlightUploadIds: inFlightUploadIds,
                onNotReady: { upload, tx in
                    self.handleNotReadyUpload(upload, tx: tx)
                }
            )
        }

        return current
    }

    private func handleNotReadyUpload(_ upload: Upload, tx: YapDatabaseReadWriteTransaction) {
        guard let asset = upload.asset, !asset.isImporting else {
            return
        }

        if let phAsset = asset.phAsset {
            queue.async {
                var taskId: UIBackgroundTaskIdentifier = .invalid
                taskId = UIApplication.shared.beginBackgroundTask(withName: "UploadManager.import") {
                    if taskId != .invalid {
                        UIApplication.shared.endBackgroundTask(taskId)
                        taskId = .invalid
                    }
                }
                AssetFactory.load(from: phAsset, into: asset) { _ in
                    if taskId != .invalid {
                        UIApplication.shared.endBackgroundTask(taskId)
                        taskId = .invalid
                    }
                }
            }
        }
        else if asset.file?.exists == true {
            queue.async {
                var taskId: UIBackgroundTaskIdentifier = .invalid
                taskId = UIApplication.shared.beginBackgroundTask(withName: "UploadManager.ready") {
                    if taskId != .invalid {
                        UIApplication.shared.endBackgroundTask(taskId)
                        taskId = .invalid
                    }
                }

                asset.update({ asset in
                    asset.isReady = true
                }) { _ in
                    if taskId != .invalid {
                        UIApplication.shared.endBackgroundTask(taskId)
                        taskId = .invalid
                    }
                }
            }
        }
        else {
            upload.error = NSLocalizedString("Couldn't import item!", comment: "")
            upload.cancel()
            upload.paused = true
            tx.replace(upload)
        }
    }

    private func syncIaUploadsForCooldownIfNeeded() {
        guard IaCooldownManager.shared.isActive else { return }

        var changed = false
        Db.writeConn?.readWrite { tx in
            changed = UploadQueueService.syncIaUploadsForCooldown(tx: tx)
        }

        if changed {
            notifyUploadGridRefresh()
        }
    }

    private func pendingIa503Count() -> Int {
        var count = 0
        Db.bgRwConn?.read { tx in
            count = UploadQueueService.uploads(in: .ia503Retry, tx: tx).count
        }
        return count
    }

    private func hasPendingIa503Retry() -> Bool {
        pendingIa503Count() > 0
    }

    /// True when any IA upload is waiting in `.normal` (a batch that should be allowed to try).
    private func hasNormalPendingIaUploads() -> Bool {
        var found = false
        Db.bgRwConn?.read { tx in
            for upload in UploadQueueService.uploads(in: .normal, tx: tx) {
                upload.preheat(tx)
                guard !upload.paused, upload.state != .uploaded, upload.asset?.space is IaSpace else {
                    continue
                }
                found = true
                break
            }
        }
        return found
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
                if let asset = upload.asset {
                    cancelBackgroundUploadTasksForAssetSync(asset, keepNewestDuplicate: false)
                }
                clearInFlight(id)
                current?.cancel()
                current?.paused = true
                
                storeCurrent()
                
                current = nil
            } else {
                // If asset is already uploaded, just clear the error state — don't re-upload.
                if let asset = current?.asset, asset.isUploaded {
                    current?.cancel()
                    current?.paused = false
                    current?.error = nil
                    current?.progress = 1.0
                    storeCurrent()
                    current = nil
                    return
                }
                // Retry (e.g. from media grid) while this job is still `current` — previously did nothing.
                if let asset = current?.asset {
                    cancelBackgroundUploadTasksForAssetSync(asset, keepNewestDuplicate: false)
                }
                clearInFlight(id)
                current?.cancel()
                current?.paused = false
                current?.error = nil
                current?.tries = 0
                current?.lastTry = nil
                current?.progress = 0
                current?.queueSection = .normal
                current?.autoRetryCount = 0
                current?.deferredLargeThisBackground = false
                manualRetryId = id
                if let upload = current {
                    Db.bgRwConn?.readWrite { tx in
                        UploadQueueService.moveToEnd(of: .normal, upload: upload, tx: tx)
                        upload.paused = false
                        upload.error = nil
                        upload.tries = 0
                        upload.lastTry = nil
                        upload.progress = 0
                        tx.replace(upload)
                    }
                }
                if let space = current?.asset?.space {
                    space.tries = 0
                    space.lastTry = nil
                    Db.bgRwConn?.readWrite { tx in
                        tx.replace(space, forKey: space.id, inCollection: Space.collection)
                    }
                }
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
                        // If asset is already uploaded, just clear error — don't re-upload.
                        if let asset = upload.asset, asset.isUploaded {
                            upload.paused = false
                            upload.error = nil
                            upload.progress = 1.0
                            tx.replace(upload)
                            return
                        }

                        upload.paused = false
                        upload.error = nil
                        upload.tries = 0
                        upload.lastTry = nil
                        upload.progress = 0
                        upload.autoRetryCount = 0
                        upload.deferredLargeThisBackground = false
                        manualRetryId = id

                        UploadQueueService.moveToEnd(of: .normal, upload: upload, tx: tx)
                        upload.paused = false
                        upload.error = nil

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
    /// Smallest progress shown while an upload is in flight but bytes haven't registered yet.
    private static let minVisibleProgress: Double = 0.03

    /// Live fraction for an in-flight upload (includes `liveProgress` not yet written to the DB).
    func displayProgress(for uploadId: String) -> Double? {
        var value: Double?
        let work = {
            guard self.inFlightUploadIds.contains(uploadId) else { return }
            let live = self.current?.id == uploadId ? (self.current?.progress ?? 0) : 0
            value = live > 0.001 ? live : Self.minVisibleProgress
        }
        if isOnUploadQueue {
            work()
        } else {
            queue.sync(execute: work)
        }
        return value
    }

    /// Called from Conduit as soon as a `Progress` object exists for an in-flight upload.
    func attachLiveProgress(_ progress: Progress, for uploadId: String) {
        let work = {
            guard self.current?.id == uploadId else { return }
            self.current?.liveProgress = progress
        }
        // Background Conduit runs on this queue — `queue.sync` here would deadlock.
        if isOnUploadQueue {
            work()
        } else {
            queue.sync(execute: work)
        }
        notifyUploadGridRefresh()
    }

    /// Writes live progress into the DB so the grid can switch from pending spinner to progress ring.
    private func persistUploadProgressToGrid() {
        guard let upload = current else { return }
        guard upload.error == nil else { return }

        let live = upload.progress
        guard live > 0 else { return }

        upload.progress = live
        lastStoredProgress = live
        lastProgressStoreDate = Date()
        storeCurrent()
    }

    private func storeCurrent(force: Bool = false) {
        if !force && (isInBackground || Self.isBackgroundSessionRelaunch) {
            return
        }
        if let upload = current {
            if upload.liveProgress != nil {
                upload.progress = upload.progress
            }
            Db.writeConn?.readWrite { tx in
                // Could be, that our cache is out of sync with the database,
                // due to background upload not triggering a `yapDatabaseModified` callback.
                // Don't write non-existing objects into it: use `replace` instead of `setObject`.
                tx.replace(upload)
            }
            notifyUploadGridRefresh()
        }
    }

    private func notifyUploadGridRefresh() {
        guard !shouldDeferUIRefresh else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .uploadGridRefresh, object: nil)
        }
    }
    
    private func endBackgroundTask(_ result: UIBackgroundFetchResult) {
        debug("#endBackgroundTask result=\(result)")

        let end = { [self] in
            guard backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }

        if Thread.isMainThread {
            end()
        } else {
            // Never main.sync — foreground UI refresh on main can deadlock with the upload queue.
            DispatchQueue.main.async(execute: end)
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

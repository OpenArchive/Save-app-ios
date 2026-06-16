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
        beginInFlightBackgroundTaskSynchronously()
    }

    /// Called synchronously from `sceneDidEnterBackground` on the main thread.
    func willEnterBackground() {
        isInBackground = true
        logUploadMemory("app_background")
        if UploadMemoryLog.pendingUploadCount() > 0 {
            beginInFlightBackgroundTaskSynchronously()
        }
        queue.async {
            self.handleEnterBackgroundOnQueue()
        }
    }

    /// Call after new uploads are written to the database (e.g. from Preview).
    func notifyUploadsEnqueued() {
        queue.async {
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
            self.logUploadMemory("app_foreground")
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
        queue.sync {
            // Persist any in-memory progress skipped while backgrounded.
            storeCurrent(force: true)
            ensurePollingActive()
            uploadNext()
        }
        Self.isBackgroundSessionRelaunch = false
        DispatchQueue.main.async {
            handler?()
        }
    }
    
    /**
     This handles a finished file upload task, but ignores metadata files and file chunks.
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debug("#task:didCompleteWithError task=\(task), state=\(self.getTaskStateName(task.state)), url=\(task.originalRequest?.url?.absoluteString ?? "nil") error=\(String(describing: error))")

        // Clean up temp file if it exists
        if let tempFilePath = task.taskDescription, !tempFilePath.isEmpty {
            let tempFileURL = URL(fileURLWithPath: tempFilePath)
            try? FileManager.default.removeItem(at: tempFileURL)
        }

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
            clearInFlight(current.id)
            current.cancel()
            current.trackCancellation(reason: "user_deleted")
            self.current = nil
            self.lastProgressDate = nil
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
                return self.endBackgroundTask(.newData)
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
            IaCooldownManager.shared.recordIaSuccess(on: queue)
            Db.writeConn?.readWrite { tx in
                UploadQueueService.demoteAllIa503ToNormal(tx: tx)
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
        manualRetryId = nil

        logUploadMemory("upload_success", upload: upload)

        notifyUploadGridRefresh()
        clearInFlight(upload.id)
        ensurePollingActive()
        uploadNext()
        endBackgroundTaskIfQueueIdle(.newData)
    }

    private func handleUploadFailure(upload: Upload, asset: Asset, error: Error?) {
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

    private func handleIa503Failure(upload: Upload) {
        upload.error = UploadQueuePolicy.iaBusyMessage
        upload.paused = false
        upload.lastTry = nil
        upload.progress = 0

        let cooldownStillActive = IaCooldownManager.shared.isActive
        let extendCooldown = !cooldownStillActive
            && IaCooldownManager.shared.hadExpiredCooldownBefore503()

        Db.writeConn?.readWrite { tx in
            UploadQueueService.markAllPendingIa503(tx: tx)
        }

        upload.error = UploadQueuePolicy.iaBusyMessage
        upload.queueSection = .ia503Retry
        upload.progress = 0
        upload.paused = false
        upload.lastTry = nil

        if cooldownStillActive {
            IaCooldownLog.log(
                "cooldown_still_active",
                minutes: IaCooldownManager.shared.scheduledMinutes,
                remainingSec: IaCooldownManager.shared.remainingSeconds,
                reason: "503_while_waiting"
            )
            return
        }

        if extendCooldown {
            IaCooldownManager.shared.onRetryFailedWith503(on: queue)
        } else {
            IaCooldownManager.shared.startCooldown(on: queue, reason: "ia503")
        }
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
                    guard let id = self.current?.id else { return }
                    if self.backgroundTransferStartedIds.contains(id) {
                        return
                    }
                    self.clearInFlight(id)
                    self.current?.cancel()
                    self.current = nil
                    self.lastProgressDate = nil
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

    /// End the uploadNext background task only when no further work needs foreground prep.
    private func endBackgroundTaskIfQueueIdle(_ result: UIBackgroundFetchResult) {
        if (isInBackground || Self.isBackgroundSessionRelaunch), hasRunnableUploadWork() {
            return
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

            return endBackgroundTask(.noData)
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
        lastStoredProgress = 0
        lastProgressStoreDate = nil

        Db.writeConn?.readWrite { tx in
            if let collection = asset.collection,
               collection.closed == nil
            {
                collection.close()

                tx.replace(collection)
            }

            tx.replace(upload)
        }

        // Run Conduit on a worker thread so the upload queue stays free for the
        // progress timer (WebDAV blocks synchronously during folder setup and transfer).
        let uploadId = upload.id
        let bgSession = backgroundSession
        let fgSession = foregroundSession
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = Conduit.get(for: asset, bgSession, fgSession)?.upload(uploadId: uploadId)
            self?.queue.async {
                guard let self, self.current?.id == uploadId else { return }
                self.persistUploadProgressToGrid()
            }
        }

        if !(isInBackground || Self.isBackgroundSessionRelaunch) {
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

    /// Called from Conduit once the main file is handed to a background `URLSession`.
    func notifyBackgroundTransferEnqueued() {
        queue.async { [weak self] in
            guard let self else { return }
            if let id = self.current?.id ?? self.inFlightUploadIds.first {
                self.backgroundTransferStartedIds.insert(id)
            }
            self.endInFlightBackgroundTask()
            self.endBackgroundTask(.newData)
        }
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

        if backgroundTransferStartedIds.contains(id) {
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
                if cooldownActive,
                   upload.asset?.space is IaSpace,
                   upload.id != retryId {
                    return
                }

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
            if let upload = self.current,
               upload.error == nil,
               upload.hasProgressChanged() {

                self.debug("#progress tracker changed for \(upload))")

                self.current?.progress = upload.progress
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
               let lastProgress = self.lastProgressDate,
               Date().timeIntervalSince(lastProgress) > Self.uploadTimeoutInterval {
                self.debug("#timeout detected for \(upload)")
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
        queue.sync {
            guard self.inFlightUploadIds.contains(uploadId) else { return }
            let live = self.current?.id == uploadId ? (self.current?.progress ?? 0) : 0
            value = live > 0.001 ? live : Self.minVisibleProgress
        }
        return value
    }

    /// Called from Conduit as soon as a `Progress` object exists for an in-flight upload.
    func attachLiveProgress(_ progress: Progress, for uploadId: String) {
        queue.sync {
            guard self.current?.id == uploadId else { return }
            self.current?.liveProgress = progress
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

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
    /// Prefer `prepareForBackgroundURLSession(identifier:completionHandler:)` so WebDAV/IA route correctly.
    static func prepareForBackgroundURLSession(completionHandler: @escaping () -> Void) {
        prepareForBackgroundURLSession(identifier: nil, completionHandler: completionHandler)
    }

    static func prepareForBackgroundURLSession(
        identifier: String?,
        completionHandler: @escaping () -> Void
    ) {
        if let identifier, WebDavUploadManager.handlesSessionIdentifier(identifier) {
            WebDavUploadManager.prepareForBackgroundURLSession(completionHandler: completionHandler)
            return
        }
        if let identifier, IaUploadManager.handlesSessionIdentifier(identifier) {
            IaUploadManager.prepareForBackgroundURLSession(completionHandler: completionHandler)
            return
        }
        // Legacy shared session id (`…background`) — migration of in-flight only.
        backgroundCompletionHandler = completionHandler
        isBackgroundSessionRelaunch = true
        shared.isInBackground = true
    }

    /// Called when the user opens the app — clears silent background-session wake state.
    static func noteUserForegrounded() {
        isBackgroundSessionRelaunch = false
        WebDavUploadManager.noteUserForegrounded()
        IaUploadManager.noteUserForegrounded()
    }

    /// Upload id of the in-flight job (for WebDAV/IA bytes-started tracking).
    var currentUploadId: String? { current?.id }

    func currentWebDavUpload() -> Upload? {
        guard let current, current.asset?.space is WebDavSpace else { return nil }
        return current
    }

    func currentIaUpload() -> Upload? {
        guard let current, current.asset?.space is IaSpace else { return nil }
        return current
    }

    /// WebDAV background session finished events — advance global queue, then call `then`
    /// only after the next WebDAV main PUT is on the background session (or nothing left).
    func handleWebDavBackgroundSessionFinishedEvents(then: @escaping () -> Void) {
        // REVERT TO EXACT OLD PATTERN - simple and synchronous
        queue.async { [weak self] in
            guard let self else { return }
            self.storeCurrent(force: true)
            self.ensurePollingActive()
            self.uploadNext()
        }
        Self.isBackgroundSessionRelaunch = false
        DispatchQueue.main.async(execute: then)
    }

    /// IA background session finished events — same hold pattern as WebDAV (main + meta).
    func handleIaBackgroundSessionFinishedEvents(then: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async(execute: then)
                return
            }
            self.storeCurrent(force: true)
            self.ensurePollingActive()
            self.uploadNext()
            self.queue.async {
                self.uploadNext()
                self.finishIaBackgroundWakeIfReady(then: then, attempt: 0)
            }
        }
    }

    /// Do not tell iOS the wake is done until the next WebDAV file's BG PUT exists —
    /// otherwise uploads stop after 3 files. Hold for up to 10 seconds (matches IA pattern).
    private func finishWebDavBackgroundWakeIfReady(then: @escaping () -> Void, attempt: Int) {
#if DEBUG
        let currentFile = current?.filename ?? "nil"
        let isWebDav = current?.asset?.space is WebDavSpace
        let bytesStarted: Bool
        if let id = current?.id {
            bytesStarted = hasBytesTransferStarted(id)
        } else {
            bytesStarted = false
        }
        let hasWork = hasRunnableUploadWork()
        if attempt == 0 || attempt % 10 == 0 {
            print("[UploadDiag] finishWebDavWake attempt=\(attempt)/100 current=\(currentFile) isWebDav=\(isWebDav) bytesStarted=\(bytesStarted) hasWork=\(hasWork)")
        }
#endif

        // If there's a WebDAV upload in progress but bytes haven't started, wait for it
        if let id = current?.id,
           current?.asset?.space is WebDavSpace,
           !hasBytesTransferStarted(id) {
            beginInFlightBackgroundTaskSynchronously()
            // iOS needs 3-5 seconds to enqueue next background PUT. Hold for up to 10 seconds.
            // Poll every 100ms, max 100 attempts = 10 seconds (matches IA pattern)
            if attempt < 100 {
                queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.finishWebDavBackgroundWakeIfReady(then: then, attempt: attempt + 1)
                }
                return
            }
#if DEBUG
            print("[UploadDiag] webdav 10s timeout - calling handler (id=\(id) still starting)")
#endif
        }

        // If there's no current upload but there IS pending WebDAV work, wait briefly
        else if current == nil && hasRunnableUploadWork() && hasPendingWebDavUploads() {
            beginInFlightBackgroundTaskSynchronously()
            // Retry uploadNext every 3 attempts (300ms), but detect repeated failures
            if attempt % 3 == 0 {
                let hadCurrent = current != nil
                uploadNext()
                // If uploadNext() fails to start work after 5 tries (1.5 seconds), give up
                if !hadCurrent && current == nil && attempt >= 15 {
#if DEBUG
                    print("[UploadDiag] webdav wake - uploadNext failed 5 times, aborting")
#endif
                    Self.isBackgroundSessionRelaunch = false
                    DispatchQueue.main.async(execute: then)
                    return
                }
            }
            // Max 10 seconds. Poll every 100ms, max 100 attempts (matches IA pattern)
            if attempt < 100 {
                queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.finishWebDavBackgroundWakeIfReady(then: then, attempt: attempt + 1)
                }
                return
            }
#if DEBUG
            print("[UploadDiag] webdav 10s timeout - calling handler (next file not started)")
#endif
        }

#if DEBUG
        let hasPendingWebdav = hasPendingWebDavUploads()
        print("[UploadDiag] finishWebDavWake EXIT attempt=\(attempt) current=\(currentFile) hasWork=\(hasWork) hasPendingWebdav=\(hasPendingWebdav) bytesStarted=\(bytesStarted)")
#endif
        Self.isBackgroundSessionRelaunch = false
        DispatchQueue.main.async(execute: then)
    }

    /// Hold the system completion handler until the current IA main (and meta, if waiting)
    /// is on the background session — otherwise multi-file BG chains stall.
    private func finishIaBackgroundWakeIfReady(then: @escaping () -> Void, attempt: Int) {
        if let id = current?.id, current?.asset?.space is IaSpace {
            let waitingMeta = IaConduit.isAwaitingMeta(id) && !IaConduit.hasMetaEnqueued(id)
            let waitingBytes = !hasBytesTransferStarted(id)
            if waitingMeta || waitingBytes {
                beginInFlightBackgroundTaskSynchronously()
                if attempt < 100 { // ~10s
                    queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.finishIaBackgroundWakeIfReady(then: then, attempt: attempt + 1)
                    }
                    return
                }
#if DEBUG
                print("[UploadDiag] ia wake ending without ready id=\(id) meta=\(waitingMeta) bytes=\(waitingBytes)")
#endif
            }
        }
        DispatchQueue.main.async(execute: then)
    }

    /// WebDAV task completed on `WebDavUploadManager`'s session — finish via shared `done`.
    /// Must run synchronously so `didComplete` finishes starting the next PUT before
    /// `urlSessionDidFinishEvents` runs.
    func handleWebDavTaskCompleted(uploadId: String, error: Error?, url: URL?) {
        let work = { [weak self] in
            guard let self else { return }
            if self.current?.id != uploadId,
               let found = self.resolveUpload(for: uploadId) {
                self.current = found
            }
            WebDavUploadManager.shared.clearBytesStarted(uploadId)
            self.done(uploadId, error, url)
        }
        if isOnUploadQueue {
            work()
        } else {
            queue.sync(execute: work)
        }
    }

    /// IA task completed on `IaUploadManager`'s session — sync so meta / next main
    /// is enqueued before `urlSessionDidFinishEvents`.
    func handleIaTaskCompleted(task: URLSessionTask, url: URL, error: Error?) {
        let work = { [weak self] in
            guard let self else { return }
            let action = UploadBackendRouter.ia.handleTaskCompleted(
                task: task,
                url: url,
                error: error,
                current: self.current
            )
            switch action {
            case .ignore, .wait:
                return
            case let .done(uploadId, doneError, doneUrl):
                if self.current?.id != uploadId,
                   let found = self.resolveUpload(for: uploadId) {
                    self.current = found
                }
                IaUploadManager.shared.clearBytesStarted(uploadId)
                self.done(uploadId, doneError, doneUrl)
            }
        }
        if isOnUploadQueue {
            work()
        } else {
            queue.sync(execute: work)
        }
    }

    /// True when the app is backgrounded *or* silently relaunched for a background URLSession.
    /// Use this (not bare `isInBackground`) for any path that must not touch the foreground session.
    var isEffectivelyBackgrounded: Bool {
        isInBackground
            || Self.isBackgroundSessionRelaunch
            || WebDavUploadManager.isBackgroundSessionRelaunch
            || IaUploadManager.isBackgroundSessionRelaunch
    }

    /// Skip main-thread grid refreshes while backgrounded or during a background-session wake.
    var shouldDeferUIRefresh: Bool {
        isEffectivelyBackgrounded
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
     A session, which is enabled for background uploading (legacy identifier only).
     
     WebDAV main-file PUTs use `WebDavUploadManager.backgroundSession`.
     IA main/meta PUTs use `IaUploadManager.backgroundSession`.
     
     This needs to be tied to an object, otherwise the `URLSession` will get
     destroyed during the request and the request will break with error -999.
     */
    private var backgroundSession: URLSession {
        if _backgroundSession == nil {
            // Legacy identifier — WebDAV uses `…webdav.background`, IA uses `…ia.background`.
            let conf = URLSessionConfiguration.background(withIdentifier:
                                                            "\(Bundle.main.bundleIdentifier ?? "").background")
            
            conf.isDiscretionary = false
            conf.shouldUseExtendedBackgroundIdleMode = true
            conf.sessionSendsLaunchEvents = true
            
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

        UploadBackendRouter.ia.install(host: .init(
            queue: queue,
            sessions: {
                IaUploadManager.shared.sessions
            },
            onWakeContinue: { [weak self] in
                self?.ensurePollingActive()
                self?.uploadNext()
            },
            onCooldownUiRefresh: { [weak self] in
                self?.notifyUploadGridRefresh()
            }
        ))

        // Recreate the background session when iOS relaunches us for finished uploads.
        let wakingForBackgroundSession = Self.backgroundCompletionHandler != nil
            || IaUploadManager.isBackgroundSessionRelaunch
        if wakingForBackgroundSession {
            isInBackground = true
            _ = backgroundSession
            _ = IaUploadManager.shared.backgroundSession
        }

        restart(skipInitialUploadNext: wakingForBackgroundSession)
    }
    
    func reinitSession() {
        _backgroundSession = nil
        _foregroundSession = nil
        WebDavUploadManager.shared.reinitSession()
        IaUploadManager.shared.reinitSession()
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

        // Eagerly create sessions so uploads can hand off before suspension.
        _ = backgroundSession
        _ = WebDavUploadManager.shared.backgroundSession
        _ = IaUploadManager.shared.backgroundSession
        
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

        UploadBackendRouter.ia.syncBusyUiIfNeeded()

        if UploadBackendRouter.ia.shouldCancelInFlightForActiveCooldown() {
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
        WebDavUploadManager.shared.prepareForPossibleBackground()
        IaUploadManager.shared.prepareForPossibleBackground()
        beginInFlightBackgroundTaskSynchronously()
    }

    /// Called synchronously from `sceneDidEnterBackground` on the main thread.
    func willEnterBackground() {
        isInBackground = true
        WebDavUploadManager.shared.willEnterBackground()
        IaUploadManager.shared.willEnterBackground()
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
            UploadBackendRouter.ia.onNewBatchEnqueued(queue: self.queue)

            // Pre-create WebDAV folders immediately (not waiting for sceneWillResignActive)
            // so folders are ready before app backgrounds and 30-second UIBackgroundTask starts.
            // Do this async to avoid blocking the upload queue.
            if !self.isEffectivelyBackgrounded {
                DispatchQueue.global(qos: .userInitiated).async {
                    WebDavUploadManager.shared.preparePendingFolders()
                }
            }

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
        WebDavUploadManager.shared.becameActive()
        IaUploadManager.shared.becameActive()
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
            UploadBackendRouter.ia.syncBusyUiIfNeeded()
            if UploadBackendRouter.ia.shouldCancelInFlightForActiveCooldown() {
                if let id = self.current?.id {
                    self.clearInFlight(id)
                }
                self.current?.cancel()
                self.current = nil
                self.lastProgressDate = nil
            }
            if !Self.isBackgroundSessionRelaunch
                && !WebDavUploadManager.isBackgroundSessionRelaunch
                && !IaUploadManager.isBackgroundSessionRelaunch {
                self.cleanup()
            }
            self.storeCurrent(force: true)

            let missedCooldownWake = UploadBackendRouter.ia.consumeMissedCooldownWakeOnForeground()

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
                    // If the user opened the app during the silent wake, finish foreground bookkeeping now.
                    if UIApplication.shared.applicationState == .active {
                        UploadManager.shared.setBackgroundState(false)
                        UploadManager.shared.becameActive()
                    }
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

        // Backend-specific temp cleanup (IA encoded taskDescription only).
        UploadBackendRouter.ia.cleanupTempFile(for: task)

        queue.async { [weak self] in
            self?.handleBackgroundUploadTaskCompleted(task, error: error)
        }
    }

    /// Shared completion handler for URLSession delegate callbacks and lifecycle reconciliation.
    /// IA session only — WebDAV completions are handled by `WebDavUploadManager`.
    private func handleBackgroundUploadTaskCompleted(_ task: URLSessionTask, error: Error?) {
        guard task.state == .completed,
              let url = task.originalRequest?.url,
              (error as? NSError)?.code != -999 /* cancelled */
        else {
            return
        }

        var effectiveError = error
        if effectiveError == nil,
           let httpResponse = task.response as? HTTPURLResponse,
           httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            effectiveError = SaveError.http(status: httpResponse.statusCode)
        }

        // IA tagged tasks only on this session.
        if let parsed = IaConduit.parseTaskDescription(task.taskDescription),
           parsed.kind == "ia-main" || parsed.kind == "ia-meta" {
            let action = UploadBackendRouter.ia.handleTaskCompleted(
                task: task,
                url: url,
                error: effectiveError,
                current: current
            )
            switch action {
            case .ignore, .wait:
                return
            case let .done(uploadId, error, doneUrl):
                if current?.id != uploadId,
                   let found = resolveUpload(for: uploadId) {
                    current = found
                }
                done(uploadId, error, doneUrl)
            }
            return
        }

        // Untagged completions on the IA session are ignored (WebDAV uses its own session).
#if DEBUG
        debug("didComplete ignored non-IA task on IA session file=\(url.lastPathComponent)")
#endif
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

        // IA-only success side effects (cooldown unpark, derive, pacing). WebDAV stays immediate.
        let iaAfterSuccess: UploadAfterSuccessAction?
        if space is IaSpace {
            let sessions = IaUploadManager.shared.sessions
            iaAfterSuccess = UploadBackendRouter.ia.afterSuccess(
                upload: upload,
                asset: asset,
                url: url,
                sessions: sessions,
                uploadQueue: queue
            )
            if case .continueAfterDelay = iaAfterSuccess {
                notifyUploadGridRefresh()
            }
        } else {
            iaAfterSuccess = nil
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

        if let iaAfterSuccess {
            switch iaAfterSuccess {
            case .continueImmediately:
                uploadNext()
                endBackgroundTaskIfQueueIdle(.newData)
            case let .continueAfterDelay(delay):
                queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.uploadNext()
                    self?.endBackgroundTaskIfQueueIdle(.newData)
                }
            }
        } else {
            // WebDAV known-good: meta was enqueued before main in copyMetadata;
            // chain the next BG PUT immediately.
            uploadNext()
            endBackgroundTaskIfQueueIdle(.newData)
        }
    }

    private func handleUploadFailure(upload: Upload, asset: Asset, error: Error?) {
        if asset.space is IaSpace {
            UploadBackendRouter.ia.afterFailure(upload: upload, asset: asset)
        }
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
            UploadBackendRouter.ia.handle503Failure(upload: upload, queue: queue)

        case .duplicateExists:
            break
        }

        upload.freezeProgressForPersistence()

        Db.writeConn?.readWrite { tx in
            tx.replace(upload)
            tx.replace(asset)
        }

        if failureKind == .ia503 {
            UploadBackendRouter.ia.syncBusyUiIfNeeded()
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

        guard isEffectivelyBackgrounded else {
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
        } else if isEffectivelyBackgrounded {
            DispatchQueue.main.sync(execute: begin)
        } else {
            DispatchQueue.main.async(execute: begin)
        }
    }

    /// End the uploadNext background task once the current file is on a background URLSession
    /// (or there is nothing left to prep). Do **not** hold the task for the whole remaining queue —
    /// iOS expires UIBackgroundTask in ~30s; the next wake comes from the background session.
    private func endBackgroundTaskIfQueueIdle(_ result: UIBackgroundFetchResult) {
        if isEffectivelyBackgrounded {
            if let id = current?.id, !hasBytesTransferStarted(id) {
                // Still in mkdir/meta prep — keep running until the BG PUT is enqueued.
                return
            }
        }
        endBackgroundTask(result)
    }

    private func runUploadNextWork() {
        debug("#uploadNext")

        if !isEffectivelyBackgrounded {
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

            // If there's an upload in progress, fail it with connectivity error so it gets retried
            if let upload = current, let asset = upload.asset {
                let connectivityError = NSError(
                    domain: NSURLErrorDomain,
                    code: URLError.notConnectedToInternet.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: connectivityBlockMessage ?? UploadQueuePolicy.noNetworkMessage]
                )
                handleUploadFailure(
                    upload: upload,
                    asset: asset,
                    error: connectivityError
                )
            }

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
            UploadBackendRouter.ia.logBlockingIfNeeded()

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
        UploadBackendRouter.ia.noteResumingFrom503Queue(upload: upload)
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

        if asset.space is WebDavSpace {
            // WebDAV executor owns sessions + folder prep + BG PUT.
            let uploadId = upload.id
            let inline = isEffectivelyBackgrounded
            let start = { [weak self] in
                WebDavUploadManager.shared.startUpload(
                    uploadId: uploadId,
                    asset: asset,
                    inline: true
                )
                self?.queue.async {
                    guard let self, self.current?.id == uploadId else { return }
                    self.persistUploadProgressToGrid()
                }
            }
            // Collection close bookkeeping (shared).
            Db.writeConn?.readWrite { tx in
                if let collection = asset.collection,
                   collection.closed == nil
                {
                    collection.close()
                    tx.replace(collection)
                }
                tx.replace(upload)
            }

            if inline {
                start()
            } else {
                DispatchQueue.global(qos: .userInitiated).async(execute: start)
                endBackgroundTask(.newData)
            }
            return
        }

        if asset.space is IaSpace {
            // IA executor owns sessions + main→meta BG PUTs.
            let uploadId = upload.id
            let inline = isEffectivelyBackgrounded
            let start = { [weak self] in
                IaUploadManager.shared.startUpload(
                    uploadId: uploadId,
                    asset: asset,
                    inline: true
                )
                self?.queue.async {
                    guard let self, self.current?.id == uploadId else { return }
                    self.persistUploadProgressToGrid()
                }
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

            if inline {
                start()
            } else {
                DispatchQueue.global(qos: .userInitiated).async(execute: start)
                endBackgroundTask(.newData)
            }
            return
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

        // Unknown space type — best-effort via Conduit factory on legacy sessions.
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

        if isEffectivelyBackgrounded {
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

    // MARK: - Background URLSession task lifecycle

    /// Cancels background PUT tasks when the user removes an upload from the queue.
    func cancelBackgroundUploadTasksForRemovedUpload(_ upload: Upload) {
        if let asset = upload.asset, asset.space is IaSpace {
            UploadBackendRouter.ia.afterFailure(upload: upload, asset: asset)
            IaUploadManager.shared.cancelBackgroundTasks(
                forUploadId: upload.id,
                filename: upload.filename,
                keepNewestDuplicate: false
            )
            return
        }
        if let asset = upload.asset, asset.space is WebDavSpace {
            WebDavUploadManager.shared.cancelBackgroundTasks(
                forFilename: upload.filename,
                keepNewestDuplicate: false
            )
            return
        }
        backgroundSession.getAllTasks { tasks in
            self.cancelBackgroundUploadTasks(
                tasks: tasks,
                filename: upload.filename,
                space: upload.asset?.space,
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

    private func cancelBackgroundUploadTasksForFilenameSync(
        _ filename: String,
        space: Space?,
        keepNewestDuplicate: Bool
    ) {
        if space is IaSpace {
            let uploadId = current?.filename == filename ? (current?.id ?? "") : ""
            IaUploadManager.shared.cancelBackgroundTasks(
                forUploadId: uploadId,
                filename: filename,
                keepNewestDuplicate: keepNewestDuplicate
            )
            return
        }
        let sem = DispatchSemaphore(value: 0)
        backgroundSession.getAllTasks { tasks in
            self.cancelBackgroundUploadTasks(
                tasks: tasks,
                filename: filename,
                space: space,
                keepNewestDuplicate: keepNewestDuplicate
            )
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
    }

    private func cancelBackgroundUploadTasksForAssetSync(_ asset: Asset, keepNewestDuplicate: Bool) {
        if asset.space is WebDavSpace {
            WebDavUploadManager.shared.cancelBackgroundTasks(
                forFilename: asset.filename,
                keepNewestDuplicate: keepNewestDuplicate
            )
            return
        }
        if asset.space is IaSpace {
            // Prefer upload id from current if matching filename.
            let uploadId = current?.filename == asset.filename ? (current?.id ?? "") : ""
            if !uploadId.isEmpty {
                IaUploadManager.shared.cancelBackgroundTasks(
                    forUploadId: uploadId,
                    filename: asset.filename,
                    keepNewestDuplicate: keepNewestDuplicate
                )
            } else {
                IaUploadManager.shared.cancelBackgroundTasks(
                    forUploadId: "",
                    filename: asset.filename,
                    keepNewestDuplicate: keepNewestDuplicate
                )
            }
            return
        }
        cancelBackgroundUploadTasksForFilenameSync(
            asset.filename,
            space: asset.space,
            keepNewestDuplicate: keepNewestDuplicate
        )
    }

    private func cancelBackgroundUploadTasks(
        tasks: [URLSessionTask],
        filename: String,
        space: Space?,
        keepNewestDuplicate: Bool
    ) {
        // IA session cancel path (WebDAV uses WebDavUploadManager.cancelBackgroundTasks).
        let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            UploadBackendRouter.ia.shouldCancelBackgroundTask(task, filename: filename)
        }

        let keepId = keepNewestDuplicate
            ? matching.filter { UploadBackendTaskHelpers.filename(of: $0) == filename }.map(\.taskIdentifier).max()
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
            print("[UploadDiag] cancelled \(cancelled) IA background task(s) for \(filename) keepNewest=\(keepNewestDuplicate) keepId=\(keepId.map(String.init) ?? "nil")")
        }
#endif
    }

    /// Drops duplicate and orphan background PUTs so only the newest task for the current upload remains.
    private func pruneStaleBackgroundUploadTasks(tasks: [URLSessionTask], keeping: Upload) {
        if keeping.asset?.space is WebDavSpace {
            WebDavUploadManager.shared.pruneStaleTasks(keepingFilename: keeping.filename)
            return
        }
        if keeping.asset?.space is IaSpace {
            IaUploadManager.shared.pruneStaleTasks(keeping: keeping)
            return
        }

        pruneOrphanBackgroundUploadTasksIA(tasks: tasks, keeping: keeping)

        let sameFile = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            UploadBackendRouter.ia.taskMatchesInFlight(task, upload: keeping)
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
            print("[UploadDiag] pruned \(cancelled) duplicate IA background task(s) for \(keeping.filename) keepId=\(keepId.map(String.init) ?? "nil")")
        }
#endif
    }

    private func pruneOrphanBackgroundUploadTasksIA(tasks: [URLSessionTask], keeping: Upload) {
        var cancelled = 0

        for task in tasks {
            guard let uploadTask = task as? URLSessionUploadTask,
                  task.state != .completed && task.state != .canceling
            else {
                continue
            }

            if UploadBackendRouter.ia.shouldKeepDuringPrune(uploadTask, keeping: keeping) {
                continue
            }

            guard UploadBackendTaskHelpers.isMainAssetBackgroundUploadTask(task)
                || IaConduit.parseTaskDescription(task.taskDescription)?.kind == "ia-meta"
            else {
                continue
            }

            task.cancel()
            cancelled += 1
        }

#if DEBUG
        if cancelled > 0 {
            print("[UploadDiag] pruned \(cancelled) orphan IA background task(s) keeping=\(keeping.filename)")
        }
#endif
    }

    /// After foreground↔background transitions, URLSession may not deliver `didComplete` promptly.
    private func reconcileInFlightBackgroundTasks() {
        guard !inFlightUploadIds.isEmpty else { return }
        guard let upload = current, inFlightUploadIds.contains(upload.id) else { return }

        if upload.asset?.space is WebDavSpace {
            WebDavUploadManager.shared.reconcileInFlight(upload: upload) { [weak self] task in
                self?.queue.async {
                    self?.handleWebDavTaskCompleted(
                        uploadId: upload.id,
                        error: nil,
                        url: task.originalRequest?.url
                    )
                }
            }
            return
        }

        if upload.asset?.space is IaSpace {
            IaUploadManager.shared.reconcileInFlight(upload: upload) { [weak self] task in
                guard let self, let url = task.originalRequest?.url else { return }
                self.queue.async {
                    self.handleIaTaskCompleted(task: task, url: url, error: nil)
                }
            }
            return
        }

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

        // WebDAV reconciles via WebDavUploadManager.
        guard upload.asset?.space is IaSpace else { return }

        let transferStarted = hasBytesTransferStarted(upload.id)
        if !transferStarted {
            reconcilePrepPhaseStall(upload: upload, tasks: tasks)
            return
        }

        pruneStaleBackgroundUploadTasks(tasks: tasks, keeping: upload)

        let filename = upload.filename
        let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            UploadBackendRouter.ia.taskMatchesInFlight(task, upload: upload)
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
        let checkAfter: TimeInterval = isInBackground ? 90 : 45
        guard stalled > checkAfter else { return }

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

        if WebDavUploadManager.shared.fileExistsOnServer(
            url,
            expectedSize: expectedSize,
            credential: space.credential
        ) {
#if DEBUG
            print("[UploadDiag] high-progress — file already on server, completing file=\(upload.filename)")
#endif
            done(upload.id, nil, url)
            return
        }

        let giveUpAfter: TimeInterval = isInBackground ? 600 : 300
        guard stalled > giveUpAfter else { return }

#if DEBUG
        print("[UploadDiag] high-progress give-up after \(Int(stalled))s — resetting file=\(upload.filename)")
#endif
        debug("#reconcile high-progress give-up for \(upload.filename) — resetting for retry")
        resetStalledInFlightUpload(upload)
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
            // Keep background task alive if there are more uploads pending (WebDAV or IA).
            // This bridges the gap between uploads so iOS doesn't suspend the app.
            // NOTE: This may trigger 30-second warning with large queues, but maintains speed.
            if !self.hasRunnableUploadWork() {
                self.endInFlightBackgroundTask()
            }
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
            || WebDavUploadManager.shared.hasBytesTransferStarted(uploadId)
            || IaUploadManager.shared.hasBytesTransferStarted(uploadId)
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
            guard UploadBackendTaskHelpers.isMainAssetBackgroundUploadTask(task),
                  UploadBackendTaskHelpers.filename(of: task) == filename,
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

        // Only clear bytes-started for the relevant backend to avoid state corruption
        let isWebDav = WebDavUploadManager.shared.hasBytesTransferStarted(id)
        let isIa = IaUploadManager.shared.hasBytesTransferStarted(id)

        if isWebDav {
            WebDavUploadManager.shared.clearBytesStarted(id)
        }
        if isIa {
            IaUploadManager.shared.clearBytesStarted(id)
        }

        // End background task if no in-flight uploads remain.
        // Note: We keep task alive if more work is pending to maintain upload speed,
        // but always end if nothing is in-flight to prevent leaks.
        if inFlightUploadIds.isEmpty {
            if !hasRunnableUploadWork() {
                endInFlightBackgroundTask()
            }
        }
    }

    /// Must run on the main thread while the app is still active — async dispatch is too late after backgrounding.
    private func beginInFlightBackgroundTaskSynchronously() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.beginInFlightBackgroundTaskSynchronously() }
            return
        }
        guard inFlightBackgroundTask == .invalid else { return }

        let taskId = UIApplication.shared.beginBackgroundTask(withName: "UploadManager.inFlight") { [weak self] in
            guard let self else { return }
            let capturedTaskId = self.inFlightBackgroundTask
            if capturedTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(capturedTaskId)
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
        let retryId = manualRetryId
        var found = false
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, stop: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }

                if self.inFlightUploadIds.contains(upload.id) {
                    return
                }

                if UploadBackendRouter.ia.isParkedByCooldown(upload, manualRetryId: retryId) {
                    return
                }

                upload.preheat(tx)

                found = true
                stop = true
            }
        }
        return found
    }

    private func hasPendingWebDavUploads() -> Bool {
        var found = false
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, stop: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }
                upload.preheat(tx)
                if upload.asset?.space is WebDavSpace {
                    found = true
                    stop = true
                }
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
                if !self.isEffectivelyBackgrounded,
                   self.current?.id == upload.id {
                    self.persistUploadProgressToGrid()
                    self.notifyUploadGridRefresh()
                }
            }

            if !self.isEffectivelyBackgrounded,
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

            if !self.hasActiveCurrentUpload() {
                UploadBackendRouter.ia.pollExpiredCooldownIfNeeded {
                    self.ensurePollingActive()
                    self.uploadNext()
                }
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
            UploadBackendRouter.ia.logPollingSuspendedIfWaitingOnCooldown()
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
        let background = isEffectivelyBackgrounded
        let cooldownActive = UploadBackendRouter.ia.isCooldownActive

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
                    if asset.space is IaSpace {
                        UploadBackendRouter.ia.afterFailure(upload: upload, asset: asset)
                    }
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
        if !force && isEffectivelyBackgrounded {
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

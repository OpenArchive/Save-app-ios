//
//  IaUploadManager.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//
//  Internet Archive upload executor. Owns FG check_limit/derive session + BG
//  main/meta PUTs. Does NOT own global queue order — UploadManager dispatches
//  here when the next job is IA. 503 / pacing policy stays in IaUploadCoordinator.
//

import Foundation
import UIKit

final class IaUploadManager: NSObject, URLSessionTaskDelegate {

    static let shared = IaUploadManager()

    static var backgroundSessionIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "org.openarchive.save").ia.background"
    }

    /// True while iOS relaunched the app for this manager's background URLSession.
    private(set) static var isBackgroundSessionRelaunch = false

    private static var backgroundCompletionHandler: (() -> Void)?

    private let stateLock = NSLock()
    private var _isInBackground = false
    private(set) var isInBackground: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isInBackground
        }
        set {
            stateLock.lock()
            _isInBackground = newValue
            stateLock.unlock()
        }
    }

    var isEffectivelyBackgrounded: Bool {
        isInBackground || Self.isBackgroundSessionRelaunch
    }

    private var _backgroundSession: URLSession?
    private var _foregroundSession: URLSession?

    /// Background session — main + meta.json PUTs (survives suspend / kill).
    var backgroundSession: URLSession {
        if _backgroundSession == nil {
            let conf = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
            conf.isDiscretionary = false
            conf.shouldUseExtendedBackgroundIdleMode = true
            conf.sessionSendsLaunchEvents = true
            _backgroundSession = URLSession(
                configuration: URLSessionConfiguration.improved(conf),
                delegate: self,
                delegateQueue: nil
            )
        }
        return _backgroundSession!
    }

    /// Foreground session — check_limit / queueDerive only when not suspended.
    var foregroundSession: URLSession {
        if _foregroundSession == nil {
            _foregroundSession = URLSession(
                configuration: URLSessionConfiguration.improved(),
                delegate: self,
                delegateQueue: nil
            )
        }
        return _foregroundSession!
    }

    var sessions: UploadSessions {
        UploadSessions(background: backgroundSession, foreground: foregroundSession)
    }

    private var inFlightBackgroundTask = UIBackgroundTaskIdentifier.invalid
    private var bytesStartedUploadIds = Set<String>()

    private override init() {
        super.init()
        if Self.backgroundCompletionHandler != nil {
            isInBackground = true
            Self.isBackgroundSessionRelaunch = true
            _ = backgroundSession
        }
    }

    // MARK: - App / shell lifecycle

    static func prepareForBackgroundURLSession(completionHandler: @escaping () -> Void) {
        backgroundCompletionHandler = completionHandler
        isBackgroundSessionRelaunch = true
        shared.isInBackground = true
        _ = shared.backgroundSession
        // Resume meta if we were killed after main succeeded.
        IaConduit.resumePendingMetasIfNeeded(on: shared.backgroundSession)
    }

    static func noteUserForegrounded() {
        isBackgroundSessionRelaunch = false
    }

    static func handlesSessionIdentifier(_ identifier: String) -> Bool {
        identifier == backgroundSessionIdentifier
            || identifier.hasSuffix(".ia.background")
    }

    func setBackgroundState(_ inBackground: Bool) {
        isInBackground = inBackground
    }

    func prepareForPossibleBackground() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.prepareForPossibleBackground() }
            return
        }
        guard hasPendingIaUploads() else { return }
        beginInFlightBackgroundTaskSynchronously()
    }

    func willEnterBackground() {
        isInBackground = true
        if hasPendingIaUploads() {
            beginInFlightBackgroundTaskSynchronously()
        }
    }

    func becameActive() {
        isInBackground = false
        Self.isBackgroundSessionRelaunch = false
        IaConduit.resumePendingMetasIfNeeded(on: backgroundSession)
    }

    func reinitSession() {
        _backgroundSession = nil
        _foregroundSession = nil
    }

    // MARK: - Start an IA job (dispatched by UploadManager)

    func startUpload(uploadId: String, asset: Asset, inline: Bool) {
        let bg = backgroundSession
        let fg = foregroundSession
        let work = {
            _ = IaConduit(asset, bg, fg).upload(uploadId: uploadId)
        }

        if inline || isEffectivelyBackgrounded {
            work()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }
    }

    func notifyBackgroundTransferEnqueued(uploadId: String?) {
        if let uploadId {
            bytesStartedUploadIds.insert(uploadId)
        } else if let id = UploadManager.shared.currentUploadId {
            bytesStartedUploadIds.insert(id)
        }
        endInFlightBackgroundTask()
        UploadManager.shared.notifyBackgroundTransferEnqueued()
    }

    func hasBytesTransferStarted(_ uploadId: String) -> Bool {
        bytesStartedUploadIds.contains(uploadId)
    }

    func clearBytesStarted(_ uploadId: String) {
        bytesStartedUploadIds.remove(uploadId)
    }

    // MARK: - Cancel / prune / reconcile

    func cancelBackgroundTasks(forUploadId uploadId: String, filename: String, keepNewestDuplicate: Bool) {
        IaConduit.cancelPendingMeta(uploadId: uploadId)
        let sem = DispatchSemaphore(value: 0)
        backgroundSession.getAllTasks { tasks in
            let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
                UploadBackendRouter.ia.shouldCancelBackgroundTask(task, filename: filename)
                    || IaConduit.parseTaskDescription(task.taskDescription)?.uploadId == uploadId
            }
            let keepId = keepNewestDuplicate ? matching.map(\.taskIdentifier).max() : nil
            for task in matching where task.state != .completed && task.state != .canceling {
                if let keepId, task.taskIdentifier == keepId { continue }
                task.cancel()
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
    }

    func pruneStaleTasks(keeping: Upload) {
        backgroundSession.getAllTasks { tasks in
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

            let sameFile = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
                UploadBackendRouter.ia.taskMatchesInFlight(task, upload: keeping)
            }
            let keepId = sameFile.map(\.taskIdentifier).max()
            for task in sameFile where task.state != .completed && task.state != .canceling {
                guard let keepId, task.taskIdentifier != keepId else { continue }
                task.cancel()
                cancelled += 1
            }
#if DEBUG
            if cancelled > 0 {
                print("[IaUpload] pruned \(cancelled) stale task(s) keeping=\(keeping.filename)")
            }
#endif
        }
    }

    func reconcileInFlight(upload: Upload, onMissedComplete: (URLSessionTask) -> Void) {
        IaConduit.resumePendingMetasIfNeeded(on: backgroundSession)

        let sem = DispatchSemaphore(value: 0)
        var snapshot: [URLSessionTask] = []
        backgroundSession.getAllTasks { tasks in
            snapshot = tasks
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)

        pruneStaleTasks(keeping: upload)

        let matching = snapshot.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            UploadBackendRouter.ia.taskMatchesInFlight(task, upload: upload)
        }.sorted { $0.taskIdentifier > $1.taskIdentifier }

        if let task = matching.first, task.state == .completed {
            onMissedComplete(task)
        }
    }

    // MARK: - URLSessionDelegate

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = Self.backgroundCompletionHandler
        Self.backgroundCompletionHandler = nil

        IaConduit.resumePendingMetasIfNeeded(on: backgroundSession)

        UploadManager.shared.handleIaBackgroundSessionFinishedEvents {
            Self.isBackgroundSessionRelaunch = false
            handler?()
            if UIApplication.shared.applicationState == .active {
                IaUploadManager.noteUserForegrounded()
                IaUploadManager.shared.setBackgroundState(false)
                UploadManager.noteUserForegrounded()
                UploadManager.shared.setBackgroundState(false)
                UploadManager.shared.becameActive()
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
#if DEBUG
        let file = task.originalRequest?.url?.lastPathComponent ?? "?"
        let http = (task.response as? HTTPURLResponse)?.statusCode ?? -1
        print("[IaUpload] didComplete file=\(file) HTTP=\(http) error=\(String(describing: error))")
#endif

        UploadBackendRouter.ia.cleanupTempFile(for: task)

        guard task.state == .completed,
              let url = task.originalRequest?.url,
              (error as? NSError)?.code != -999
        else {
            return
        }

        var effectiveError = error
        if effectiveError == nil,
           let httpResponse = task.response as? HTTPURLResponse,
           httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            effectiveError = SaveError.http(status: httpResponse.statusCode)
        }

        guard let parsed = IaConduit.parseTaskDescription(task.taskDescription),
              parsed.kind == "ia-main" || parsed.kind == "ia-meta"
        else {
            return
        }

        // Sync into shell so meta / next main is enqueued before finishEvents.
        UploadManager.shared.handleIaTaskCompleted(
            task: task,
            url: url,
            error: effectiveError
        )
    }

    // MARK: - Private

    private func hasPendingIaUploads() -> Bool {
        var found = false
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, stop: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }
                upload.preheat(tx)
                if upload.asset?.space is IaSpace {
                    found = true
                    stop = true
                }
            }
        }
        return found
    }

    private func beginInFlightBackgroundTaskSynchronously() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.beginInFlightBackgroundTaskSynchronously() }
            return
        }
        guard inFlightBackgroundTask == .invalid else { return }
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "IaUpload.inFlight") { [weak self] in
            guard let self else { return }
            let capturedTaskId = self.inFlightBackgroundTask
            if capturedTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(capturedTaskId)
                self.inFlightBackgroundTask = .invalid
            }
        }
        inFlightBackgroundTask = taskId
    }

    private func endInFlightBackgroundTask() {
        let end = { [self] in
            if inFlightBackgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(inFlightBackgroundTask)
                inFlightBackgroundTask = .invalid
            }
        }
        if Thread.isMainThread {
            end()
        } else {
            DispatchQueue.main.async(execute: end)
        }
    }
}

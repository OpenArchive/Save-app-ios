//
//  WebDavUploadManager.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//
//  WebDAV / private-server upload executor. Owns FG prep + BG main PUTs.
//  Does NOT own global queue order — UploadManager dispatches the next job here
//  only when that job is WebDAV. No IA types or cooldown logic in this file.
//

import Foundation
import UIKit
import Regex

final class WebDavUploadManager: NSObject, URLSessionTaskDelegate {

    static let shared = WebDavUploadManager()

    static var backgroundSessionIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "org.openarchive.save").webdav.background"
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

    /// Background session — main file + meta.json PUTs (survives suspend / kill).
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

    /// Foreground session — mkdir / PROPFIND / meta sidecar only.
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
    }

    static func noteUserForegrounded() {
        isBackgroundSessionRelaunch = false
    }

    static func handlesSessionIdentifier(_ identifier: String) -> Bool {
        identifier == backgroundSessionIdentifier
            || identifier.hasSuffix(".webdav.background")
    }

    func setBackgroundState(_ inBackground: Bool) {
        isInBackground = inBackground
    }

    /// Called from sceneWillResignActive — finish folder prep while we still can.
    func prepareForPossibleBackground() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.prepareForPossibleBackground() }
            return
        }
        guard hasPendingWebDavUploads() else { return }
        preparePendingFolders()
        beginInFlightBackgroundTaskSynchronously()
    }

    func willEnterBackground() {
        isInBackground = true
        if hasPendingWebDavUploads() {
            beginInFlightBackgroundTaskSynchronously()
        }
    }

    func becameActive() {
        isInBackground = false
        Self.isBackgroundSessionRelaunch = false
        // Reconcile happens via UploadManager shell calling us when current is WebDAV.
        reconcileIfNeeded()
    }

    func reinitSession() {
        _backgroundSession = nil
        _foregroundSession = nil
        WebDavConduit.clearFolderCache()
    }

    func notifyEnqueued() {
        preparePendingFolders()
    }

    // MARK: - Start a WebDAV job (dispatched by UploadManager)

    /// Prepare folders (FG only) and start `WebDavConduit` on this manager's sessions.
    func startUpload(uploadId: String, asset: Asset, inline: Bool) {
        if !isEffectivelyBackgrounded, let space = asset.space as? WebDavSpace {
            WebDavConduit.prepareCollectionFolders(
                for: asset,
                session: foregroundSession,
                credential: space.credential
            )
        }

        let bg = backgroundSession
        let fg = foregroundSession
        let work = {
            _ = WebDavConduit(asset, bg, fg).upload(uploadId: uploadId)
        }

        if inline || isEffectivelyBackgrounded {
            work()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        }
    }

    func prepareBeforeStart(asset: Asset) {
        guard !isEffectivelyBackgrounded,
              let space = asset.space as? WebDavSpace
        else {
            return
        }
        WebDavConduit.prepareCollectionFolders(
            for: asset,
            session: foregroundSession,
            credential: space.credential
        )
    }

    func preparePendingFolders() {
        guard !isEffectivelyBackgrounded else { return }

        var prepared = Set<String>()
        Db.bgRwConn?.read { tx in
            tx.iterateKeysAndObjects(inCollection: Upload.collection) { (_: String, upload: Upload, _: inout Bool) in
                guard !upload.paused, upload.state != .uploaded else { return }
                upload.preheat(tx)
                guard let asset = upload.asset,
                      let space = asset.space as? WebDavSpace,
                      !asset.isUploaded
                else {
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

    // MARK: - Cancel / prune (WebDAV rules only)

    func cancelBackgroundTasks(forFilename filename: String, keepNewestDuplicate: Bool) {
        let sem = DispatchSemaphore(value: 0)
        backgroundSession.getAllTasks { tasks in
            let matching = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
                self.isMainAssetTask(task) && self.taskFilename(task) == filename
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

    func pruneStaleTasks(keepingFilename: String) {
        backgroundSession.getAllTasks { tasks in
            var cancelled = 0
            for task in tasks {
                guard let uploadTask = task as? URLSessionUploadTask,
                      self.isMainAssetTask(task),
                      task.state != .completed && task.state != .canceling,
                      let name = self.taskFilename(uploadTask)
                else {
                    continue
                }
                if name == keepingFilename { continue }
                task.cancel()
                cancelled += 1
            }

            let sameFile = tasks.compactMap { $0 as? URLSessionUploadTask }.filter { task in
                self.isMainAssetTask(task) && self.taskFilename(task) == keepingFilename
            }
            let keepId = sameFile.map(\.taskIdentifier).max()
            for task in sameFile where task.state != .completed && task.state != .canceling {
                guard let keepId, task.taskIdentifier != keepId else { continue }
                task.cancel()
                cancelled += 1
            }
#if DEBUG
            if cancelled > 0 {
                print("[WebDavUpload] pruned \(cancelled) stale task(s) keeping=\(keepingFilename)")
            }
#endif
        }
    }

    func reconcileInFlight(upload: Upload, onMissedComplete: (URLSessionTask) -> Void) {
        let sem = DispatchSemaphore(value: 0)
        var snapshot: [URLSessionTask] = []
        backgroundSession.getAllTasks { tasks in
            snapshot = tasks
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)

        pruneStaleTasks(keepingFilename: upload.filename)

        let matching = snapshot.compactMap { $0 as? URLSessionUploadTask }.filter { task in
            guard let url = task.originalRequest?.url,
                  taskFilename(task) == upload.filename
            else {
                return false
            }
            return taskUrlMatches(url, upload: upload)
        }.sorted { $0.taskIdentifier > $1.taskIdentifier }

        if let task = matching.first, task.state == .completed {
            onMissedComplete(task)
        }
    }

    func fileExistsOnServer(_ url: URL, expectedSize: Int64, credential: URLCredential?) -> Bool {
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

    // MARK: - URLSessionDelegate

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = Self.backgroundCompletionHandler
        Self.backgroundCompletionHandler = nil

        // Let the shell advance the *global* queue (next may be IA), then call iOS.
        UploadManager.shared.handleWebDavBackgroundSessionFinishedEvents {
            Self.isBackgroundSessionRelaunch = false
            handler?()
            if UIApplication.shared.applicationState == .active {
                WebDavUploadManager.noteUserForegrounded()
                WebDavUploadManager.shared.setBackgroundState(false)
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
        print("[WebDavUpload] didComplete file=\(file) HTTP=\(http) error=\(String(describing: error))")
#endif

        // Clean temp meta files; never finish the job on sidecar completion.
        if let desc = task.taskDescription, desc.hasPrefix("webdav-meta:") {
            let path = String(desc.dropFirst("webdav-meta:".count))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            return
        }
        if task.originalRequest?.url?.lastPathComponent.hasSuffix(".meta.json") == true {
            return
        }

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

        guard let action = completionAction(task: task, url: url, error: effectiveError) else {
            return
        }

        UploadManager.shared.handleWebDavTaskCompleted(
            uploadId: action.uploadId,
            error: action.error,
            url: action.url
        )
    }

    // MARK: - Completion matching (strict — known-good WebDAV rules)

    private struct CompletionResult {
        let uploadId: String
        let error: Error?
        let url: URL?
    }

    private func completionAction(task: URLSessionTask, url: URL, error: Error?) -> CompletionResult? {
        let filename = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent

        if filename.hasSuffix(".meta.json") {
            return nil
        }
        for file in Asset.Files.allCases where !file.isInternal {
            if filename =~ "\(file.rawValue)$" {
                return nil
            }
        }
        guard task is URLSessionUploadTask, filename !~ "\\d{15}-\\d{15}" else {
            return nil
        }

        if let current = UploadManager.shared.currentWebDavUpload(),
           current.filename == filename {
            guard taskUrlMatches(url, upload: current) else {
#if DEBUG
                print("[WebDavUpload] ignored URL mismatch for current file=\(filename)")
#endif
                return nil
            }
            return CompletionResult(uploadId: current.id, error: error, url: url)
        }

        if let found = Db.bgRwConn?.find(
            group: UploadsView.groups.first,
            in: UploadsView.name,
            where: { (tx, upload: inout Upload) in
                guard !upload.paused else { return false }
                upload.preheat(tx)
                guard upload.filename == filename && upload.isReady else { return false }
                guard upload.asset?.space is WebDavSpace else { return false }
                return true
            }
        ), taskUrlMatches(url, upload: found) {
            return CompletionResult(uploadId: found.id, error: error, url: url)
        }

#if DEBUG
        print("[WebDavUpload] ignored orphan file=\(filename) url=\(url.absoluteString)")
#endif
        return nil
    }

    private func taskUrlMatches(_ url: URL, upload: Upload) -> Bool {
        guard let asset = upload.asset,
              asset.space is WebDavSpace,
              let collectionName = asset.collection?.name
        else {
            return false
        }
        let path = url.path.removingPercentEncoding ?? url.path
        let file = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard file == asset.filename else { return false }
        return path.contains(collectionName)
    }

    private func isMainAssetTask(_ task: URLSessionTask) -> Bool {
        guard task is URLSessionUploadTask,
              let filename = task.originalRequest?.url?.lastPathComponent
        else {
            return false
        }
        if filename =~ "\\d{15}-\\d{15}" { return false }
        for file in Asset.Files.allCases where !file.isInternal {
            if filename =~ "\(file.rawValue)$" { return false }
        }
        return true
    }

    private func taskFilename(_ task: URLSessionUploadTask) -> String? {
        guard let name = task.originalRequest?.url?.lastPathComponent else { return nil }
        return name.removingPercentEncoding ?? name
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

    private func reconcileIfNeeded() {
        // Shell drives reconcile when it has a current WebDAV upload.
    }

    private func beginInFlightBackgroundTaskSynchronously() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.beginInFlightBackgroundTaskSynchronously() }
            return
        }
        guard inFlightBackgroundTask == .invalid else { return }
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "WebDavUpload.inFlight") { [weak self] in
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

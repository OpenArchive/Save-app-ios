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
import BackgroundTasks
import Photos
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
        (reachability?.connection ?? Reachability.Connection.unavailable == .unavailable)
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
    
    private var globalPause = false
    
    /**
     Polls tracked Progress objects and updates `Update` objects every second.
     */
    var progressTimer: DispatchSourceTimer?

    /// Tracks when the current upload last made progress, for timeout detection.
    private var lastProgressDate: Date?

    /// Tracks when we last persisted progress to DB, for throttling writes.
    private var lastStoreDate: Date?

    private var progressTimerActive = false

    /// How long a non-IA upload can be stuck without progress before timing out.
    private static let uploadTimeoutInterval: TimeInterval = 60
    private static let iaUploadTimeoutInterval: TimeInterval = 5 * 60

    private static let schedulerInterval: TimeInterval = 10
    private static let schedulerInitialDelay: TimeInterval = 5
    private static let progressTrackingInterval: TimeInterval = 1
    private static let progressStoreThrottleInterval: TimeInterval = 5

    /// Chunk filenames use the format "%015d-%015d" (31 chars, all digits and one dash).
    private static func isChunkFilename(_ name: String) -> Bool {
        guard name.count == 31 else { return false }
        let dashIndex = name.index(name.startIndex, offsetBy: 15)
        return name[dashIndex] == "-"
            && name[name.startIndex..<dashIndex].allSatisfy(\.isNumber)
            && name[name.index(after: dashIndex)...].allSatisfy(\.isNumber)
    }

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
    
    
    /// Session config used for uploads and WebDAV operations (e.g. browse folders).
    public class func improvedSessionConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        return URLSessionConfiguration.improved(conf)
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
        
        try? reachability?.startNotifier()
        
        if let oldTimer = progressTimer, !progressTimerActive {
            oldTimer.resume()
        }
        progressTimer?.cancel()
        progressTimerActive = false

        progressTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        progressTimer?.schedule(deadline: .now(), repeating: .seconds(Int(Self.progressTrackingInterval)))
        progressTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            if let upload = self.current,
               upload.hasProgressChanged() {

                self.debug("#progress tracker changed for \(upload))")

                self.current?.progress = upload.progress
                self.lastProgressDate = Date()

                if self.lastStoreDate == nil ||
                    Date().timeIntervalSince(self.lastStoreDate!) >= Self.progressStoreThrottleInterval {
                    self.storeCurrent()
                    self.lastStoreDate = Date()
                }
            }

            // Timeout detection: if current upload has no progress for too long, mark as error.
            if let upload = self.current,
               let lastProgress = self.lastProgressDate,
               Date().timeIntervalSince(lastProgress) > self.uploadTimeoutInterval(for: upload) {
                self.debug("#timeout detected for \(upload)")
                upload.cancel()
                upload.error = NSLocalizedString("Upload timed out.", comment: "")
                upload.tries += 1
                upload.retryAfterUntil = nil
                self.storeCurrent()
                self.current = nil
                self.lastProgressDate = nil
                self.stopProgressTracking()
                self.uploadNext()
            }
        }
        
        scheduler = Timer(fireAt: Date().addingTimeInterval(Self.schedulerInitialDelay),
                          interval: Self.schedulerInterval,
                          target: self, selector: #selector(uploadNext),
                          userInfo: nil, repeats: true)

        RunLoop.main.add(scheduler!, forMode: .common)
    }

    private func startProgressTracking() {
        guard !progressTimerActive else { return }
        progressTimerActive = true
        progressTimer?.resume()
    }

    private func stopProgressTracking() {
        guard progressTimerActive else { return }
        progressTimerActive = false
        progressTimer?.suspend()
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

        // Clean up temp file if it exists
        if let tempFilePath = task.taskDescription, !tempFilePath.isEmpty {
            let tempFileURL = URL(fileURLWithPath: tempFilePath)
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // Ignore incomplete tasks.
        guard task.state == .completed,
              let url = task.originalRequest?.url
        else {
            return
        }

        // Cancelled tasks: mark as error and move to next upload.
        if (error as? NSError)?.code == -999 {
            debug("#task:cancelled — marking error and moving to next")
            queue.async {
                if let upload = self.current, upload.filename == url.lastPathComponent {
                    self.done(upload.id, error, url)
                }
            }
            return
        }

        let filename = url.lastPathComponent

        // Ignore Metadata files.
        for file in Asset.Files.allCases {
            if !file.isInternal && filename.hasSuffix(file.rawValue) {
                return
            }
        }

        guard task is URLSessionUploadTask && !Self.isChunkFilename(filename) else {
            return
        }

        var effectiveError = error
        if let httpResponse = task.response as? HTTPURLResponse {
            debug("#task:httpStatus=\(httpResponse.statusCode) url=\(url.absoluteString)")
            if effectiveError == nil && !(200...299).contains(httpResponse.statusCode) {
                let retryAfter = retryAfterSeconds(from: httpResponse)
                effectiveError = SaveError.http(status: httpResponse.statusCode, retryAfter: retryAfter)
            }
        }

        queue.async {
            if self.current?.filename == filename {
                self.done(self.current?.id, effectiveError, url)
            } else {
                if let found = Db.bgRwConn?.find(group: UploadsView.groups.first, in: UploadsView.name, where: { (tx, upload: inout Upload) in
                    guard !upload.paused else {
                        return false
                    }
                    upload.preheat(tx)
                    guard upload.filename == filename && upload.isReady else {
                        return false
                    }
                    return true
                }) {
                    self.current = found
                    self.done(found.id, effectiveError, url)
                }
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
    private func done(_ id: String?, _ error: Error?, _ url: URL? = nil) {
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

            let space = asset.space
            let collection: Collection?

            if (error != nil || url == nil) && !asset.isUploaded {
                collection = self.handleUploadFailure(upload: upload, asset: asset, space: space, error: error, url: url)
            } else {
                collection = self.handleUploadSuccess(upload: upload, asset: asset, space: space, url: url)
            }

            self.persistDoneState(upload: upload, asset: asset, collection: collection, space: space)

            self.current = nil
            self.lastProgressDate = nil
            self.lastStoreDate = nil
            self.stopProgressTracking()

            self.endBackgroundTask(asset.isUploaded ? .newData : .failed)

            self.uploadNext()
        }

        queue.async(execute: work)
    }

    private func handleUploadFailure(upload: Upload, asset: Asset, space: Space?, error: Error?, url: URL?) -> Collection? {
        asset.setUploaded(nil)

        upload.liveProgress = nil
        upload.progress = 0

        let failureMessage = error?.friendlyMessage ?? (
            url == nil ? NSLocalizedString("No URL provided.", comment: "")
            : NSLocalizedString("Unknown error.", comment: ""))

        var didProcessActiveFailure = false
        let isInvalidIaCredentials: Bool = {
            guard space is IaSpace,
                  let saveError = error as? SaveError,
                  case .http(let status, _) = saveError else {
                return false
            }
            return status == 401
        }()

        if !upload.paused && !globalPause {
            didProcessActiveFailure = true
            if !isInvalidIaCredentials {
                space?.tries += 1
                space?.lastTry = Date()
            }

            upload.tries += 1
            if error?.isRetryable ?? false {
                upload.paused = UploadManager.maxRetries <= upload.tries
            } else {
                upload.paused = true
            }
            upload.lastTry = Date()
            upload.retryAfterUntil = retryAfterUntil(for: error)
            upload.error = isInvalidIaCredentials
                ? NSLocalizedString("Internet Archive credentials expired. Please remove and re-add your account.", comment: "")
                : failureMessage
        } else {
            upload.error = failureMessage
        }

        if didProcessActiveFailure, let backendType = space?.backendType {
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

        return nil
    }

    private func handleUploadSuccess(upload: Upload, asset: Asset, space: Space?, url: URL?) -> Collection? {
        if space is IaSpace {
            let iaConduit = IaConduit(asset, backgroundSession, foregroundSession)
            if let metadataError = iaConduit.uploadMetadataAfterContent() {
                debug("#IA metadata upload failed after content success: \(metadataError.localizedDescription)")
            }
        }

        if let url = url {
            asset.setUploaded(url)
        }
        upload.retryAfterUntil = nil

        space?.tries = 0
        space?.lastTry = nil

        let collection = asset.collection
        collection?.setUploadedNow()

        if let backendType = space?.backendType, let startTime = upload.startTime {
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

        return collection
    }

    private func persistDoneState(upload: Upload, asset: Asset, collection: Collection?, space: Space?) {
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
        
        if reachability?.connection ?? .unavailable != .unavailable {
            uploadNext()
        }
    }
    
    @objc func uploadNext() {
        if globalPause || (reachability?.connection ?? .unavailable) == .unavailable {
            return
        }

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

                let reason: String
                if Settings.wifiOnly && self.reachability?.connection == .cellular {
                    reason = "wifi_required"
                } else {
                    reason = "no_network"
                }
                trackEvent(.uploadNetworkError(reason: reason))

                return self.endBackgroundTask(.noData)
            }
            
            // Check if there's currently an item uploading which is not paused and not already uploaded.
            if !(self.current?.paused ?? true) && self.current?.state != .uploaded {
                self.debug("#uploadNext already one uploading")
                
                return self.endBackgroundTask(.noData)
            }
            
            guard let upload = self.getNext(),
                  let asset = upload.asset
            else {

                self.debug("#uploadNext nothing to upload")

                // Track upload session completion if one was in progress
                if self.sessionStartTime != nil {
                    let duration = Date().timeIntervalSince(self.sessionStartTime!)
                    let successCount = SessionManager.shared.sessionUploadsCompleted
                    let failedCount = SessionManager.shared.sessionUploadsFailed
                    let successRate = self.sessionUploadCount > 0 ? Double(successCount) / Double(self.sessionUploadCount) : 0

                    trackEvent(.uploadSessionCompleted(
                        count: self.sessionUploadCount,
                        successCount: successCount,
                        failedCount: failedCount,
                        durationSeconds: duration,
                        successRate: successRate
                    ))

                    // Reset session tracking
                    self.sessionStartTime = nil
                    self.sessionUploadCount = 0
                    self.sessionTotalSize = 0
                }

                return self.endBackgroundTask(.noData)
            }

            // Start upload session tracking if this is the first upload
            if self.sessionStartTime == nil {
                self.sessionStartTime = Date()
                self.sessionUploadCount = 0
                self.sessionTotalSize = 0
                SessionManager.shared.resetUploadCounters()
            }

            // Increment session counters
            self.sessionUploadCount += 1
            self.sessionTotalSize += asset.filesize ?? 0

            self.debug("#uploadNext try upload=\(upload)")

            let space = upload.asset?.space

            // Track upload started
            upload.startTime = Date()
            if let backendType = space?.backendType {
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

            upload.liveProgress = Conduit
                .get(for: asset, self.backgroundSession, self.foregroundSession)?
                .upload(uploadId: upload.id)

            upload.error = nil
            self.lastProgressDate = Date()
            self.lastStoreDate = nil
            self.startProgressTracking()

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

    private func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(value),
              seconds > 0 else {
            return nil
        }
        return seconds
    }

    private func retryAfterUntil(for error: Error?) -> Date? {
        guard let error = error as? SaveError,
              case .http(_, let retryAfter?) = error else {
            return nil
        }
        let jitterSeconds = Double.random(in: 0...0.5)
        return Date().addingTimeInterval(retryAfter + jitterSeconds)
    }

    private func uploadTimeoutInterval(for upload: Upload) -> TimeInterval {
        if upload.asset?.space is IaSpace {
            return Self.iaUploadTimeoutInterval
        }
        return Self.uploadTimeoutInterval
    }
    
    /**
     Fetches the next upload job from the database.
     
     Careful: Will overwrite a `current` if already there, so check before calling this!
     
     - returns: `current` for convenience or `nil` if none found.
     */
    private func getNext() -> Upload? {
        var failedUploads: [Upload] = []

        Db.bgRwConn?.read { tx in
            current = tx.find(group: UploadsView.groups.first, in: UploadsView.name) { (upload: inout Upload) in
                guard !upload.paused
                        && upload.state != .uploaded
                        && upload.nextTry.compare(Date()) == .orderedAscending
                else {
                    return false
                }

                upload.preheat(tx)

                if let space = upload.asset?.space, !space.uploadAllowed {
                    debug("#getNext circuit breaker open for space \(space.id) (tries=\(space.tries))")
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
                        } else if asset.file?.exists == true {
                            queue.async {
                                let id = UIApplication.shared.beginBackgroundTask()
                                asset.update({ asset in
                                    asset.isReady = true
                                }) { updatedAsset in
                                    UIApplication.shared.endBackgroundTask(id)
                                }
                            }
                        } else {
                            upload.error = NSLocalizedString("Couldn’t import item!", comment: "")
                            upload.cancel()
                            upload.paused = true
                            failedUploads.append(upload)
                        }
                    }
                    return false
                }

                return true
            }
        }

        if !failedUploads.isEmpty {
            Db.bgRwConn?.readWrite { tx in
                for upload in failedUploads {
                    tx.replace(upload)
                }
            }
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
                stopProgressTracking()
            } else {
                // If asset is already uploaded, just clear the error state — don't re-upload.
                if let asset = current?.asset, asset.isUploaded {
                    current?.cancel()
                    current?.paused = false
                    current?.error = nil
                    current?.progress = 1.0
                    storeCurrent()
                    current = nil
                    stopProgressTracking()
                    return
                }
                // Retry (e.g. from media grid) while this job is still `current` — previously did nothing.
                current?.cancel()
                current?.paused = false
                current?.error = nil
                current?.tries = 0
                current?.lastTry = nil
                current?.retryAfterUntil = nil
                current?.progress = 0
                if let space = current?.asset?.space {
                    space.tries = 0
                    space.lastTry = nil
                    Db.bgRwConn?.readWrite { tx in
                        tx.replace(space, forKey: space.id, inCollection: Space.collection)
                    }
                }
                storeCurrent()
                current = nil
                stopProgressTracking()
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
                        upload.retryAfterUntil = nil
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

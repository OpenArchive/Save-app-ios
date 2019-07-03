//
//  UploadManager.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase
import Reachability
import FilesProvider
import Alamofire

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
class UploadManager: Alamofire.SessionDelegate {

    static let shared = UploadManager()

    /**
     Maximum number of upload retries per upload item before giving up.
    */
    static let maxRetries = 10

    private var readConn = Db.newLongLivedReadConn()

    private var mappings = YapDatabaseViewMappings(groups: UploadsView.groups,
                                               view: UploadsView.name)

    private var uploads = [Upload]()

    var reachability: Reachability? = {
        var reachability = Reachability()
        reachability?.allowsCellularConnection = !Settings.wifiOnly

        return reachability
    }()

    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(String(describing: UploadManager.self))")

    private var globalPause = false

    /**
     Polls tracked Progress objects and updates `Update` objects every second.
    */
    lazy var progressTimer: DispatchSourceTimer = {
        let progressTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        progressTimer.schedule(deadline: .now(), repeating: .seconds(1))
        progressTimer.setEventHandler {
            Db.writeConn?.asyncReadWrite { transaction in
                for upload in self.uploads {
                    if upload.hasProgressChanged() {
                        self.debug("#progress tracker changed for \(upload))")

                        transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                    }
                }
            }
        }

        return progressTimer
    }()

    private var singleCompletionHandler: ((UIBackgroundFetchResult) -> Void)?

    private var schedule: Timer?

    private var backgroundTask = UIBackgroundTaskIdentifier.invalid


    init(_ singleCompletionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        super.init()

        self.singleCompletionHandler = singleCompletionHandler

        // Initialize mapping and current uploads.
        readConn?.read { transaction in
            self.mappings.update(with: transaction)

            (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .enumerateKeysAndObjects(inGroup: UploadsView.groups[0]) { collection, key, object, index, stop in
                    if let upload = object as? Upload {
                        self.uploads.append(upload)
                    }
            }
        }

        let nc = Db.add(observer: self, #selector(yapDatabaseModified))

        nc.addObserver(self, selector: #selector(done),
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

        schedule = Timer(fireAt: Date().addingTimeInterval(1), interval: 60,
                         target: self, selector: #selector(self.uploadNext),
                         userInfo: nil, repeats: true)

        progressTimer.resume()

        // Schedule a timer, which calls #uploadNext every 60 seconds beginning
        // in 1 second.
        RunLoop.main.add(schedule!, forMode: .common)

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        debug("#yapDatabaseModified")

        guard let notifications = readConn?.beginLongLivedReadTransaction(),
            let viewConn = readConn?.ext(UploadsView.name) as? YapDatabaseViewConnection else {
            return
        }

        if !viewConn.hasChanges(for: notifications) {
            readConn?.update(mappings: mappings)

            return
        }

        var rowChanges = NSArray()

        viewConn.getSectionChanges(nil, rowChanges: &rowChanges,
                                   for: notifications, with: mappings)

        guard let changes = rowChanges as? [YapDatabaseViewRowChange] else {
            return
        }

        // NOTE: Section 0 are `Upload`s, section 1 tracks changes in `Asset`s,
        // which is only interesting in an `.update` case, where we want to update
        // the `Asset` object referenced from an `Upload`.

        queue.async {
            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath, indexPath.section == 0 {
                        let upload = self.uploads.remove(at: indexPath.row)
                        upload.cancel()
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath, newIndexPath.section == 0 {
                        if let upload = self.readUpload(newIndexPath) {
                            self.uploads.insert(upload, at: newIndexPath.row)
                        }
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath, indexPath.section == 0 && newIndexPath.section == 0 {
                        let upload = self.uploads.remove(at: indexPath.row)
                        upload.order = newIndexPath.row
                        self.uploads.insert(upload, at: newIndexPath.row)
                    }
                case .update:
                    if let indexPath = change.indexPath {

                        // Notice changes in `Asset`s ready state.
                        // (The audio/video import took longer than the user
                        // hitting "upload".)
                        if indexPath.section > 0 {
                            if let asset = self.getAsset(indexPath) {
                                for upload in self.uploads {
                                    if upload.assetId == asset.id {
                                        upload.asset = asset
                                    }
                                }
                            }

                            break
                        }

                        if let upload = self.readUpload(indexPath) {
                            upload.liveProgress = self.uploads[indexPath.row].liveProgress
                            self.uploads[indexPath.row] = upload
                        }
                    }
                @unknown default:
                    break
                }
            }

            self.uploadNext()
        }
    }

    @objc func pause(notification: Notification) {
        let id = notification.object as? String

        debug("#pause id=\(id ?? "globally")")

        queue.async {
            var updates = [Upload]()

            if let id = id {
                guard let upload = self.get(id) else {
                    return
                }

                upload.cancel()
                upload.paused = true

                updates.append(upload)
            }
            else {
                self.globalPause = true

                for upload in self.uploads {
                    if upload.liveProgress != nil {
                        upload.cancel()

                        updates.append(upload)
                    }
                }
            }

            Db.writeConn?.asyncReadWrite { transaction in
                for upload in updates {
                    transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                }
            }
        }
    }

    @objc func unpause(notification: Notification) {
        let id = notification.object as? String

        debug("#unpause id=\(id ?? "globally")")

        queue.async {
            var updates = [Upload]()

            if let id = id {
                guard let upload = self.get(id),
                    upload.liveProgress == nil else {
                        return
                }

                self.reset(upload)

                updates.append(upload)
            }
            else {
                for upload in self.uploads {
                    if upload.tries > 0 {
                        self.reset(upload)
                    }
                }

                self.globalPause = false
            }

            Db.writeConn?.asyncReadWrite { transaction in
                for upload in updates {
                    transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)

                    if let space = upload.asset?.space {
                        transaction.setObject(space, forKey: space.id, inCollection: Space.collection)
                    }
                }

                // If objects were changed, #uploadNext is triggered via #yapDatabaseModified,
                // if no objects were changed, we need to do it explicitely, because
                // that's a state change in #globalPause, then.
                if updates.count < 1 {
                    self.uploadNext()
                }
            }
        }
    }

    @objc func done(notification: Notification) {
        debug("#done")

        guard let id = notification.object as? String else {
            singleCompletionHandler?(.failed)

            return
        }

        let error = notification.userInfo?[.error] as? Error
        let url = notification.userInfo?[.url] as? URL

        debug("#done id=\(id), error=\(String(describing: error)), url=\(url?.absoluteString ?? "nil")")

        queue.async {
            guard let upload = self.get(id),
                let asset = upload.asset else {
                    self.singleCompletionHandler?(.failed)

                    return
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

                    upload.error = error?.localizedDescription ?? (url == nil ? "No URL provided." : "Unknown error.")
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

            Db.writeConn?.asyncReadWrite { transaction in
                if asset.isUploaded {
                    transaction.removeObject(forKey: id, inCollection: Upload.collection)

                    transaction.setObject(collection, forKey: collection!.id, inCollection: Collection.collection)
                }
                else {
                    transaction.setObject(upload, forKey: id, inCollection: Upload.collection)
                }

                if let space = space {
                    transaction.setObject(space, forKey: space.id, inCollection: Space.collection)
                }

                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }

            self.singleCompletionHandler?(asset.isUploaded ? .newData : .failed)
        }
    }

    @objc func dataUsageChanged(notification: Notification) {
        let wifiOnly = notification.object as? Bool ?? false

        debug("#dataUsageChanged wifiOnly=\(wifiOnly)")

        reachability?.allowsCellularConnection = !wifiOnly

        reachabilityChanged(notification: Notification(name: .reachabilityChanged))
    }

    @objc func reachabilityChanged(notification: Notification) {
        debug("#reachabilityChanged connection=\(reachability?.connection ?? .none)")

        if reachability?.connection ?? .none != .none {
            uploadNext()
        }
    }

    @objc func uploadNext() {
        queue.async {
            self.debug("#uploadNext \(self.uploads.count) items in upload queue")

            if self.globalPause {
                return self.debug("#uploadNext globally paused")
            }

            // Check if there's at least on item currently uploading.
            if self.isUploading() {
                self.singleCompletionHandler?(.noData)

                return self.debug("#uploadNext already one uploading")
            }

            guard let upload = self.getNext(),
                let asset = upload.asset else {
                    self.singleCompletionHandler?(.noData)

                    return self.debug("#uploadNext nothing to upload")
            }

            if self.reachability?.connection ?? Reachability.Connection.none == .none {
                self.singleCompletionHandler?(.noData)

                return self.debug("#uploadNext no connection")
            }

            self.debug("#uploadNext try upload=\(upload)")

            upload.liveProgress = Conduit.get(for: asset)?.upload(uploadId: upload.id)
            upload.error = nil

            Db.writeConn?.asyncReadWrite { transaction in
                let collection = asset.collection

                if collection.closed == nil {
                    collection.close()

                    transaction.setObject(collection, forKey: collection.id, inCollection: Collection.collection)
                }

                transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
            }
        }
    }

    func debug(_ text: String) {
        #if DEBUG
        print("[\(String(describing: type(of: self)))] \(text)")
        #endif
    }

    // MARK: Private Methods

    private func get(_ id: String) -> Upload? {
        return uploads.first { $0.id == id }
    }

    private func isUploading() -> Bool {
        return uploads.first { $0.liveProgress != nil } != nil
    }

    private func getNext() -> Upload? {
        return uploads.first {
            $0.liveProgress == nil && !$0.paused && $0.isReady
                && $0.nextTry.compare(Date()) == .orderedAscending
        }
    }

    private func readUpload(_ indexPath: IndexPath) -> Upload? {
        var upload: Upload?

        readConn?.read() { transaction in
            upload = (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Upload
        }

        return upload
    }

    private func getAsset(_ indexPath: IndexPath) -> Asset? {
        var asset: Asset?

        readConn?.read() { transaction in
            asset = (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .object(at: indexPath, with: self.mappings) as? Asset
        }

        return asset
    }

    private func reset(_ upload: Upload) {
        upload.paused = false
        upload.error = nil
        upload.tries = 0
        upload.lastTry = nil
        upload.progress = 0

        // Also reset circuit-breaker. Otherwise users will get confused.
        let space = upload.asset?.space
        space?.tries = 0
        space?.lastTry = nil
    }

    private func endBackgroundTask() {
        debug("#endBackgroundTask")

        schedule?.invalidate()

        NotificationCenter.default.removeObserver(self)

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

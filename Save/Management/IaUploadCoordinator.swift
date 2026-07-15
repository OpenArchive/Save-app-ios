//
//  IaUploadCoordinator.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import UIKit

/// Internet Archive upload rules (main→meta, 503 cooldown, pacing).
/// All IA-only UploadManager behavior lives here — do not put IA policy back in UploadManager.
/// WebDAV stays inline in UploadManager (known-good path) — do not share matching rules.
final class IaUploadCoordinator {

    /// Callbacks into the shared upload shell (queue / UI refresh only).
    struct Host {
        let queue: DispatchQueue
        let sessions: () -> UploadSessions
        let onWakeContinue: () -> Void
        let onCooldownUiRefresh: () -> Void
    }

    private var host: Host?

    var isCooldownActive: Bool {
        IaCooldownManager.shared.isActive
    }

    /// Wire IA cooldown once from UploadManager.init — keep the wake handler IA-owned.
    func install(host: Host) {
        self.host = host
        IaCooldownManager.shared.configure(onWake: { [weak self] in
            host.queue.async {
                guard let self else { return }
                let shouldContinue = self.handleCooldownWake(
                    sessions: host.sessions(),
                    uploadQueue: host.queue
                )
                guard shouldContinue else { return }
                host.onWakeContinue()
            }
        }, onCooldownStarted: { [weak self] in
            _ = self?.syncBusyUiIfNeeded()
        }, queue: host.queue)
    }

    // MARK: - Lifecycle hooks (called from UploadManager shell)

    /// New batch enqueued — drop leftover 503 cooldown so the batch can try.
    func onNewBatchEnqueued(queue: DispatchQueue) {
        guard hasNormalPendingIaUploads() else { return }
        IaCooldownManager.shared.reset(on: queue, reason: "new_batch_enqueued")
    }

    /// Refresh parked IA items' busy UI while cooldown is active.
    @discardableResult
    func syncBusyUiIfNeeded() -> Bool {
        guard IaCooldownManager.shared.isActive else { return false }

        var changed = false
        Db.writeConn?.readWrite { tx in
            changed = UploadQueueService.syncIaUploadsForCooldown(tx: tx)
        }
        if changed {
            host?.onCooldownUiRefresh()
        }
        return changed
    }

    /// While cooldown is active, in-flight work should be cancelled (restart / foreground).
    func shouldCancelInFlightForActiveCooldown() -> Bool {
        IaCooldownManager.shared.isActive
    }

    /// Foreground: true if an expired cooldown should resume the queue now.
    func consumeMissedCooldownWakeOnForeground() -> Bool {
        let missed = IaCooldownManager.shared.shouldWakeForExpiredCooldown(
            pendingIa503: hasPendingIa503Retry()
        )
        if missed {
            IaCooldownLog.log(
                "cooldown_expired",
                pendingIa503: pendingIa503Count(),
                reason: "foreground"
            )
        }
        return missed
    }

    /// Progress-timer hook: resume queue if cooldown expired.
    func pollExpiredCooldownIfNeeded(onExpired: () -> Void) {
        guard IaCooldownManager.shared.shouldWakeForExpiredCooldown(
            pendingIa503: hasPendingIa503Retry()
        ) else {
            return
        }
        IaCooldownLog.log(
            "cooldown_expired",
            pendingIa503: pendingIa503Count(),
            reason: "poll"
        )
        onExpired()
    }

    func logPollingSuspendedIfWaitingOnCooldown() {
        guard IaCooldownManager.shared.isActive, pendingIa503Count() > 0 else { return }
        IaCooldownLog.log(
            "polling_suspended",
            minutes: IaCooldownManager.shared.scheduledMinutes,
            remainingSec: IaCooldownManager.shared.remainingSeconds,
            pendingIa503: pendingIa503Count(),
            reason: "waiting_cooldown"
        )
    }

    func noteResumingFrom503Queue(upload: Upload) {
        guard upload.queueSection == .ia503Retry else { return }
        if !IaCooldownManager.shared.isActive {
            IaCooldownManager.shared.markWokenForCurrentExpiry()
        }
        IaCooldownLog.log(
            "cooldown_resumed_upload",
            pendingIa503: pendingIa503Count(),
            reason: upload.filename
        )
    }

    func logBlockingIfNeeded() {
        IaCooldownManager.shared.logBlockingIfNeeded(pendingIa503: pendingIa503Count())
    }

    /// True when this upload is parked on the IA 503 section during an active cooldown.
    func isParkedByCooldown(_ upload: Upload, manualRetryId: String?) -> Bool {
        upload.queueSection == .ia503Retry
            && IaCooldownManager.shared.isActive
            && upload.id != manualRetryId
    }

    /// Park pending IA uploads and start/extend cooldown after HTTP 503.
    func handle503Failure(upload: Upload, queue: DispatchQueue) {
        upload.error = UploadQueuePolicy.iaBusyMessage
        upload.paused = false
        upload.progress = 0
        upload.queueSection = .ia503Retry
        upload.lastTry = nil

        Db.writeConn?.readWrite { tx in
            UploadQueueService.markAllPendingIa503(tx: tx)
            tx.replace(upload)
        }

        if IaCooldownManager.shared.isActive {
            IaCooldownLog.log(
                "cooldown_already_active",
                minutes: IaCooldownManager.shared.scheduledMinutes,
                remainingSec: IaCooldownManager.shared.remainingSeconds,
                reason: "503_while_waiting"
            )
            return
        }

        if IaCooldownManager.shared.hadExpiredCooldownBefore503() {
            IaCooldownLog.log("ia503", reason: "retry_still_503")
            IaCooldownManager.shared.onRetryFailedWith503(on: queue)
            return
        }

        IaCooldownLog.log("ia503", reason: "park_all")
        IaCooldownManager.shared.startCooldown(on: queue, reason: "ia503")
    }

    func pendingIa503Count() -> Int {
        var count = 0
        Db.bgRwConn?.read { tx in
            count = UploadQueueService.uploads(in: .ia503Retry, tx: tx).count
        }
        return count
    }

    func hasPendingIa503Retry() -> Bool {
        pendingIa503Count() > 0
    }

    func hasNormalPendingIaUploads() -> Bool {
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

    // MARK: - Background task completion / matching (IA only)

    func cleanupTempFile(for task: URLSessionTask) {
        if let parsed = IaConduit.parseTaskDescription(task.taskDescription) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: parsed.tempPath))
        }
    }

    func handleTaskCompleted(
        task: URLSessionTask,
        url: URL,
        error: Error?,
        current: Upload?
    ) -> UploadCompletionAction {
        let filename = url.lastPathComponent

        if let parsed = IaConduit.parseTaskDescription(task.taskDescription) {
            if parsed.kind == "ia-main" {
                let waitingForMeta = IaConduit.handleMainBackgroundComplete(
                    uploadId: parsed.uploadId,
                    mediaUrl: url,
                    error: error,
                    backgroundSession: IaUploadManager.shared.backgroundSession
                )
                if waitingForMeta {
#if DEBUG
                    print("[UploadDiag] ia-main OK uploadId=\(parsed.uploadId) — waiting for meta.json")
#endif
                    return .wait
                }
                return .done(
                    uploadId: parsed.uploadId,
                    error: error,
                    url: error == nil ? url : nil
                )
            }

            if parsed.kind == "ia-meta" {
#if DEBUG
                print("[UploadDiag] ia-meta complete uploadId=\(parsed.uploadId) HTTP=\((task.response as? HTTPURLResponse)?.statusCode ?? -1)")
#endif
                let mainUrl = IaConduit.handleMetaBackgroundComplete(uploadId: parsed.uploadId)
                return .done(uploadId: parsed.uploadId, error: nil, url: mainUrl)
            }
        }

        if filename.hasSuffix(".meta.json") || UploadBackendTaskHelpers.isProofOrSidecarFilename(filename) {
            return .ignore
        }

        guard task is URLSessionUploadTask,
              !UploadBackendTaskHelpers.isChunkFilename(filename)
        else {
            return .ignore
        }

        if let current, current.filename == filename {
            return .done(uploadId: current.id, error: error, url: url)
        }

        if let found = Db.bgRwConn?.find(group: UploadsView.groups.first, in: UploadsView.name, where: { (tx, upload: inout Upload) in
            guard !upload.paused else { return false }
            upload.preheat(tx)
            guard upload.filename == filename && upload.isReady else { return false }
            guard upload.asset?.space is IaSpace else { return false }
            return true
        }) {
            return .done(uploadId: found.id, error: error, url: url)
        }

        return .ignore
    }

    func taskMatchesInFlight(_ task: URLSessionUploadTask, upload: Upload) -> Bool {
        guard task.state != .canceling else { return false }

        if let parsed = IaConduit.parseTaskDescription(task.taskDescription),
           parsed.uploadId == upload.id {
            return true
        }

        guard let name = UploadBackendTaskHelpers.filename(of: task) else { return false }
        let metaName = upload.filename + ".meta.json"
        return name == upload.filename || name == metaName
    }

    func shouldCancelBackgroundTask(_ task: URLSessionUploadTask, filename: String) -> Bool {
        guard let name = UploadBackendTaskHelpers.filename(of: task) else { return false }

        if UploadBackendTaskHelpers.isMainAssetBackgroundUploadTask(task), name == filename {
            return true
        }

        if name == filename + ".meta.json",
           IaConduit.parseTaskDescription(task.taskDescription)?.kind == "ia-meta" {
            return true
        }

        return false
    }

    func shouldKeepDuringPrune(_ task: URLSessionUploadTask, keeping: Upload) -> Bool {
        if let parsed = IaConduit.parseTaskDescription(task.taskDescription),
           parsed.uploadId == keeping.id {
            return true
        }

        guard let name = UploadBackendTaskHelpers.filename(of: task) else { return false }
        if name == keeping.filename {
            return true
        }
        if name == keeping.filename + ".meta.json",
           IaConduit.parseTaskDescription(task.taskDescription)?.kind == "ia-meta" {
            return true
        }
        return false
    }

    func afterSuccess(
        upload: Upload,
        asset: Asset,
        url: URL?,
        sessions: UploadSessions,
        uploadQueue: DispatchQueue
    ) -> UploadAfterSuccessAction {
        IaCooldownManager.shared.recordIaSuccess(on: uploadQueue)

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

        if let url,
           let accessKey = asset.space?.username,
           let secretKey = asset.space?.password {
            // Derive uses the foreground session — defer while suspended so we
            // don't block / hang the upload chain on a silent BG wake.
            let runDerive = {
                IaConduit.queueDerive(
                    for: url,
                    accessKey: accessKey,
                    secretKey: secretKey,
                    session: sessions.foreground
                )
            }
            if UploadManager.shared.isEffectivelyBackgrounded
                || IaUploadManager.shared.isEffectivelyBackgrounded {
#if DEBUG
                print("[IaUpload] deferring queueDerive until foreground uploadId=\(upload.id)")
#endif
                DispatchQueue.main.async {
                    if UIApplication.shared.applicationState == .active {
                        runDerive()
                    }
                }
            } else {
                runDerive()
            }
        }

        // GCD timers won't fire once iOS suspends us — only pace while the app is active.
        if UploadManager.shared.isEffectivelyBackgrounded
            || IaUploadManager.shared.isEffectivelyBackgrounded {
            return .continueImmediately
        }
        return .continueAfterDelay(UploadQueuePolicy.iaSuccessPacingSeconds)
    }

    func afterFailure(upload: Upload, asset: Asset) {
        IaConduit.cancelPendingMeta(uploadId: upload.id)
    }

    /// After 503 cooldown expires: re-check IA `over_limit` before starting another PUT.
    /// When effectively backgrounded, skip blocking FG `check_limit` and try the PUT —
    /// unavailable FG networking must not extend cooldown forever.
    func handleCooldownWake(
        sessions: UploadSessions,
        uploadQueue: DispatchQueue
    ) -> Bool {
        let backgrounded = UploadManager.shared.isEffectivelyBackgrounded
            || IaUploadManager.shared.isEffectivelyBackgrounded
        if backgrounded {
            IaCooldownLog.log("check_limit_skipped", reason: "cooldown_wake_background")
            return true
        }

        if let credentials = nextLimitCheckCredentials() {
            switch IaConduit.checkLimit(
                accessKey: credentials.accessKey,
                bucket: credentials.bucket,
                session: sessions.foreground
            ) {
            case .overLimit:
                IaCooldownLog.log("check_limit_over", reason: "cooldown_wake")
                IaCooldownManager.shared.onRetryFailedWith503(on: uploadQueue)
                return false
            case .ready:
                IaCooldownLog.log("check_limit_ready", reason: "cooldown_wake")
            case .unavailable:
                IaCooldownLog.log("check_limit_unavailable", reason: "cooldown_wake")
            }
        }
        return true
    }

    private func nextLimitCheckCredentials() -> (accessKey: String, bucket: String)? {
        var result: (String, String)?
        Db.bgRwConn?.read { tx in
            let sections: [Upload.QueueSection] = [.ia503Retry, .normal]
            for section in sections {
                for upload in UploadQueueService.uploads(in: section, tx: tx) {
                    upload.preheat(tx)
                    guard !upload.paused,
                          upload.state != .uploaded,
                          let asset = upload.asset,
                          asset.space is IaSpace,
                          let accessKey = asset.space?.username, !accessKey.isEmpty
                    else {
                        continue
                    }

                    let bucket: String
                    if let publicUrl = asset.publicUrl {
                        bucket = publicUrl.deletingLastPathComponent().lastPathComponent
                    } else {
                        bucket = StringUtils.slug(
                            asset.title?.isEmpty == false
                                ? asset.title!
                                : StringUtils.stripSuffix(from: asset.filename)
                        )
                    }

                    guard !bucket.isEmpty else { continue }
                    result = (accessKey, bucket)
                    return
                }
            }
        }
        return result
    }
}

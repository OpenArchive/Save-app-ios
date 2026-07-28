//
//  UploadQueueService.swift
//  Save
//
//  Copyright © 2025 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

enum UploadQueueService {

    private static let selectableSections: [Upload.QueueSection] = [
        .normal, .ia503Retry
    ]

    // MARK: - Reorder primitives

    static func uploads(in section: Upload.QueueSection, tx: YapDatabaseReadTransaction) -> [Upload] {
        tx.findAll(group: UploadsView.groups.first, in: UploadsView.name) { upload in
            upload.queueSection == section
        }
        .sorted { $0.order < $1.order }
    }

    static func renumberOrders(in section: Upload.QueueSection, tx: YapDatabaseReadWriteTransaction) {
        let items = uploads(in: section, tx: tx)
        for (index, upload) in items.enumerated() {
            if upload.order != index {
                upload.order = index
                tx.replace(upload)
            }
        }
    }

    static func renumberAllSections(tx: YapDatabaseReadWriteTransaction) {
        for section in Upload.QueueSection.allCases {
            renumberOrders(in: section, tx: tx)
        }
    }

    static func moveToEnd(of section: Upload.QueueSection, upload: Upload, tx: YapDatabaseReadWriteTransaction) {
        let previousSection = upload.queueSection
        upload.queueSection = section
        let items = uploads(in: section, tx: tx).filter { $0.id != upload.id }
        upload.order = items.count
        tx.replace(upload)
        renumberOrders(in: section, tx: tx)
        if previousSection != section {
            renumberOrders(in: previousSection, tx: tx)
        }
    }

    /// Push a failed upload to the end of the normal queue (no separate error section).
    static func pushToEndOfQueue(_ upload: Upload, tx: YapDatabaseReadWriteTransaction) {
        upload.lastTry = nil
        moveToEnd(of: .normal, upload: upload, tx: tx)
    }

    static func demote(_ upload: Upload, to section: Upload.QueueSection, tx: YapDatabaseReadWriteTransaction) {
        upload.lastTry = nil
        moveToEnd(of: section, upload: upload, tx: tx)
    }

    // MARK: - Selection

    static func selectNext(
        tx: YapDatabaseReadWriteTransaction,
        isInBackground: Bool,
        manualRetryId: String?,
        iaCooldownActive: Bool,
        inFlightUploadIds: Set<String>,
        onNotReady: (Upload, YapDatabaseReadWriteTransaction) -> Void
    ) -> Upload? {
        for section in selectableSections {
            let items = uploads(in: section, tx: tx)

            for var upload in items {
                guard !upload.paused,
                      upload.state != .uploaded
                else {
                    continue
                }

                if inFlightUploadIds.contains(upload.id) {
                    continue
                }

                upload.preheat(tx)

                if upload.queueSection == .ia503Retry,
                   iaCooldownActive,
                   upload.id != manualRetryId {
                    continue
                }

                // New .normal IA uploads may still run during cooldown (a fresh batch should try).
                // Only the parked .ia503Retry batch stays blocked until cooldown ends / 503 again.

                if upload.queueSection == .normal,
                   upload.autoRetryCount == 0,
                   upload.tries == 0,
                   upload.nextTry.compare(Date()) != .orderedAscending {
                    continue
                }

                if !upload.isReady {
                    onNotReady(upload, tx)
                    continue
                }

                if upload.queueSection == .normal,
                   isLargeNextcloud(upload),
                   isInBackground {
                    if !upload.deferredLargeThisBackground {
                        upload.deferredLargeThisBackground = true
                        moveToEnd(of: .normal, upload: upload, tx: tx)
                    }
                    continue
                }

                tx.replace(upload)
                return upload
            }
        }

        return nil
    }

    // MARK: - IA 503 cascade

    /// Marks every pending IA upload as server-busy and moves them to the IA 503 retry section.
    static func markAllPendingIa503(tx: YapDatabaseReadWriteTransaction) {
        for section in selectableSections {
            for upload in uploads(in: section, tx: tx) {
                upload.preheat(tx)

                guard !upload.paused,
                      upload.state != .uploaded,
                      upload.asset?.space is IaSpace
                else {
                    continue
                }

                upload.error = UploadQueuePolicy.iaBusyMessage
                upload.progress = 0
                upload.paused = false
                upload.lastTry = nil

                if upload.queueSection != .ia503Retry {
                    demote(upload, to: .ia503Retry, tx: tx)
                } else {
                    tx.replace(upload)
                }
            }
        }
    }

    static func cascadeIa503AfterFailure(failedUpload: Upload, tx: YapDatabaseReadWriteTransaction) {
        let failedOrder = failedUpload.order
        let items = uploads(in: .normal, tx: tx)

        for upload in items where upload.order >= failedOrder {
            upload.preheat(tx)
            guard upload.asset?.space is IaSpace else {
                continue
            }

            upload.error = UploadQueuePolicy.iaBusyMessage
            upload.paused = false
            upload.lastTry = nil
            demote(upload, to: .ia503Retry, tx: tx)
        }
    }

    /// Refreshes busy UI on already-parked IA 503 items only.
    /// Does not touch `.normal` — a newly enqueued batch must still be allowed to try.
    @discardableResult
    static func syncIaUploadsForCooldown(tx: YapDatabaseReadWriteTransaction) -> Bool {
        var changed = false

        for upload in uploads(in: .ia503Retry, tx: tx) {
            upload.preheat(tx)

            guard !upload.paused,
                  upload.state != .uploaded,
                  upload.asset?.space is IaSpace
            else {
                continue
            }

            var itemChanged = false

            if upload.error != UploadQueuePolicy.iaBusyMessage {
                upload.error = UploadQueuePolicy.iaBusyMessage
                itemChanged = true
            }

            if upload.progress != 0 {
                upload.progress = 0
                itemChanged = true
            }

            if itemChanged {
                upload.paused = false
                upload.lastTry = nil
                tx.replace(upload)
                changed = true
            }
        }

        return changed
    }

    static func demoteAllIa503ToNormal(tx: YapDatabaseReadWriteTransaction) {
        let items = uploads(in: .ia503Retry, tx: tx)
        for upload in items {
            upload.error = nil
            upload.paused = false
            upload.lastTry = nil
            upload.autoRetryCount = 0
            upload.tries = 0
            upload.progress = 0
            moveToEnd(of: .normal, upload: upload, tx: tx)
        }
    }

    static func resetDeferredLargeFlags(tx: YapDatabaseReadWriteTransaction) {
        for upload in uploads(in: .normal, tx: tx) where upload.deferredLargeThisBackground {
            upload.deferredLargeThisBackground = false
            tx.replace(upload)
        }
    }

    // MARK: - Enqueue

    static func placeNewUpload(_ upload: Upload, tx: YapDatabaseReadWriteTransaction, iaCooldownActive: Bool) {
        // Always enqueue as a fresh try. A 503 parks the *current* pending batch via
        // markAllPendingIa503 — new batches must not inherit that error without uploading.
        _ = iaCooldownActive
        upload.queueSection = .normal
        upload.autoRetryCount = 0
        upload.deferredLargeThisBackground = false
        upload.error = nil
        tx.setObject(upload)
        moveToEnd(of: .normal, upload: upload, tx: tx)
    }

    // MARK: - Helpers

    static func isLargeNextcloud(_ upload: Upload) -> Bool {
        guard upload.asset?.space?.isNextcloud == true,
              let filesize = upload.asset?.filesize else {
            return false
        }

        return filesize > UploadQueuePolicy.largeFileThreshold
    }
}

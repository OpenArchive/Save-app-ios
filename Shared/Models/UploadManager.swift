//
//  UploadManager.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 14.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import Foundation
import YapDatabase

extension Notification.Name {
    static let uploadManagerPause = Notification.Name("uploadManagerPause")

    static let uploadManagerUnpause = Notification.Name("uploadManagerUnpause")

    static let uploadManagerDone = Notification.Name("uploadManagerDone")
}

extension AnyHashable {
    static let error = "error"
    static let url = "url"
}

class UploadManager {

    static let shared = UploadManager()

    private var readConn = Db.newLongLivedReadConn()

    private var mappings = YapDatabaseViewMappings(groups: UploadsView.groups,
                                               view: UploadsView.name)

    private var uploads = [Upload]()

    /**
     Polls tracked Progress objects and updates `Update` objects every second.
    */
    private let progressTimer: DispatchSourceTimer

    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).UploadManager")

    private init() {
        progressTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        progressTimer.schedule(deadline: .now(), repeating: .seconds(1))
        progressTimer.setEventHandler {
            Db.writeConn?.asyncReadWrite { transaction in
                for upload in self.uploads {
                    if upload.hasProgressChanged() {
                        print("[\(String(describing: type(of: self)))]#progress tracker changed for \(upload))")

                        transaction.setObject(upload, forKey: upload.id, inCollection: Upload.collection)
                    }
                }
            }
        }
        progressTimer.resume()

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

        uploadNext()

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModifiedExternally, object: nil)

        nc.addObserver(self, selector: #selector(pause),
                       name: .uploadManagerPause, object: nil)

        nc.addObserver(self, selector: #selector(unpause),
                       name: .uploadManagerUnpause, object: nil)

        nc.addObserver(self, selector: #selector(done),
                       name: .uploadManagerDone, object: nil)
    }

    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        print("[\(String(describing: type(of: self)))]#yapDatabaseModified")

        var rowChanges = NSArray()

        (readConn?.ext(UploadsView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(nil,
                               rowChanges: &rowChanges,
                               for: readConn?.beginLongLivedReadTransaction() ?? [],
                               with: mappings)

        guard let changes = rowChanges as? [YapDatabaseViewRowChange] else {
            return
        }

        queue.async {
            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath {
                        let upload = self.uploads.remove(at: indexPath.row)
                        upload.cancel()
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath,
                        let upload = self.readUpload(newIndexPath) {

                        self.uploads.insert(upload, at: newIndexPath.row)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                        let upload = self.uploads.remove(at: indexPath.row)
                        upload.order = newIndexPath.row
                        self.uploads.insert(upload, at: newIndexPath.row)
                    }
                case .update:
                    if let indexPath = change.indexPath,
                        let upload = self.readUpload(indexPath) {

                            upload.liveProgress = self.uploads[indexPath.row].liveProgress
                            self.uploads[indexPath.row] = upload
                    }
                }
            }

            self.uploadNext()
        }
    }

    @objc func pause(notification: Notification) {
        print("[\(String(describing: type(of: self)))]#pause")

        guard let id = notification.object as? String else {
            return
        }

        print("[\(String(describing: type(of: self)))]#pause id=\(id)")

        queue.async {
            guard let upload = self.get(id) else {
                return
            }

            upload.cancel()
            upload.paused = true

            Db.writeConn?.asyncReadWrite { transaction in
                transaction.setObject(upload, forKey: id, inCollection: Upload.collection)
            }
        }
    }

    @objc func unpause(notification: Notification) {
        print("[\(String(describing: type(of: self)))]#unpause")

        guard let id = notification.object as? String else {
            return
        }

        print("[\(String(describing: type(of: self)))]#unpause id=\(id)")

        queue.async {
            guard let upload = self.get(id),
                upload.liveProgress == nil else {
                    return
            }

            upload.paused = false
            upload.progress = 0
            upload.error = nil

            Db.writeConn?.asyncReadWrite { transaction in
                transaction.setObject(upload, forKey: id, inCollection: Upload.collection)
            }
        }
    }

    @objc func done(notification: Notification) {
        print("[\(String(describing: type(of: self)))]#done")

        guard let id = notification.object as? String else {
            return
        }

        let error = notification.userInfo?[.error] as? String
        let url = notification.userInfo?[.url] as? URL

        print("[\(String(describing: type(of: self)))]#done id=\(id), error=\(error ?? "nil"), url=\(url?.absoluteString ?? "nil")")

        queue.async {
            guard let upload = self.get(id),
                let asset = upload.asset else {
                    return
            }

            let collection: Collection?

            if error != nil || url == nil {
                asset.isUploaded = false

                upload.paused = true
                upload.liveProgress = nil
                upload.progress = 0
                upload.error = error ?? (url == nil ? "No URL provided." : "Unknown error.")

                collection = nil
            }
            else {
                asset.publicUrl = url
                asset.isUploaded = true

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

                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }
        }
    }


    // MARK: Private Methods

    private func get(_ id: String) -> Upload? {
        return uploads.first { $0.id == id }
    }

    private func uploadNext() {
        queue.async {
            print("[\(String(describing: type(of: self)))]#refresh \(self.uploads.count) items in upload queue")

            // Check if there's at least on item currently uploading.
            if self.isUploading() {
                print("[\(String(describing: type(of: self)))]#refresh already one uploading")
                return
            }

            guard let upload = self.getNext(),
                let asset = upload.asset else {

                    print("[\(String(describing: type(of: self)))]#refresh nothing to upload")

                    return
            }

            print("[\(String(describing: type(of: self)))]#refresh try upload=\(upload)")

            upload.liveProgress = asset.space?.upload(asset, uploadId: upload.id)
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

    private func isUploading() -> Bool {
        return uploads.first { $0.liveProgress != nil } != nil
    }

    private func getNext() -> Upload? {
        return uploads.first {
            $0.liveProgress == nil && !$0.paused && $0.asset != nil && !$0.isUploaded
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
}

//
//  Upload.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import DownloadButton
import YapDatabase

class Upload: NSObject, Item {

    // MARK: Item

    static let collection  = "uploads"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Upload", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Upload")
    }

    func compare(_ rhs: Upload) -> ComparisonResult {
        if order < rhs.order {
            return .orderedAscending
        }

        if order > rhs.order {
            return .orderedDescending
        }

        return .orderedSame
    }

    var id: String


    // MARK: Upload

    /**
     Remove uploads identified by their IDs and reorder the others, if necessary.

     - parameter ids: A list of upload IDs to remove.
    */
    class func remove(ids: [String]) {
        Db.writeConn?.asyncReadWrite { transaction in
            for id in ids {
                transaction.removeObject(forKey: id, inCollection: collection)
            }

            // Reorder uploads.
            (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .enumerateKeysAndObjects(inGroup: UploadsView.groups[0])
                { collection, key, object, index, stop in
                    if let upload = object as? Upload,
                        upload.order != index {

                        upload.order = Int(index)

                        transaction.setObject(upload, forKey: upload.id, inCollection: collection)
                    }
            }
        }
    }

    /**
     Remove an upload identified by its ID and reorder the others, if necessary.

     - parameter id: An upload ID to remove.
     */
    class func remove(id: String) {
        remove(ids: [id])
    }

    var order: Int

    private(set) var assetId: String?

    private(set) var progress: Double = 0

    private(set) var paused = false

    private var _asset: Asset?

    var asset: Asset? {
        get {
            if _asset == nil,
                let id = assetId {

                Db.bgRwConn?.read { transaction in
                    self._asset = transaction.object(forKey: id, inCollection: Asset.collection) as? Asset
                }
            }

            return _asset
        }

        set {
            assetId = newValue?.id
            _asset = nil
        }
    }

    var isUploaded: Bool {
        get {
            return asset?.isUploaded ?? false
        }
        set {
            asset?.isUploaded = newValue
        }
    }

    var state: PKDownloadButtonState {
        if isUploaded {
            return .downloaded
        }

        if paused {
            return .startDownload
        }

        if progress > 0 {
            return .downloading
        }

        return .pending
    }

    var thumbnail: UIImage? {
        return asset?.getThumbnail()
    }

    var filename: String {
        return asset!.filename
    }

    init(order: Int, asset: Asset) {
        id = UUID().uuidString
        self.order = order
        assetId = asset.id
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject(forKey: "id") as? String ?? UUID().uuidString
        order = decoder.decodeInteger(forKey: "order")
        assetId = decoder.decodeObject(forKey: "assetId") as? String
        paused = decoder.decodeBool(forKey: "paused")
        progress = decoder.decodeDouble(forKey: "progress")
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(order, forKey: "order")
        coder.encode(assetId, forKey: "assetId")
        coder.encode(paused, forKey: "paused")
        coder.encode(progress, forKey: "progress")
    }


    // TODO: This needs to move in a background upload manager object.
    func start() {

        if let asset = asset {
            paused = false

            asset.space?.upload(asset, progress: { asset, progress in

                self.progress = progress.fractionCompleted

                Db.bgRwConn?.asyncReadWrite { transaction in
                    transaction.setObject(self, forKey: self.id, inCollection: Upload.collection)
                }
            }, done: { asset in
                self.progress = 1
                self.isUploaded = true

                Db.bgRwConn?.asyncReadWrite { transaction in
                    transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                    transaction.setObject(self, forKey: self.id, inCollection: Upload.collection)
                }
            })
        }
    }

    // TODO: This needs to move in a background upload manager object.
    func pause() {
        paused = true
    }
}

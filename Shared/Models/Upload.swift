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

class Upload: NSObject, Item, YapDatabaseRelationshipNode {

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

    var order: Int

    var paused = false
    var error: String?
    var tries = 0
    var lastTry: Date?

    /**
     Returns the date after which another try should be done.

     It is calculated by adding the number of `tries` to the power of 1.5 in
     minutes to `lastTry`.

     If `lastTry` is `nil` returns the epoch.
    */
    var nextTry: Date {
        return lastTry?.addingTimeInterval(pow(Double(tries), 1.5) * 60)
            ?? Date(timeIntervalSince1970: 0)
    }

    var liveProgress: Progress?

    private var _progress: Double = 0
    var progress: Double {
        get {
            return liveProgress?.fractionCompleted ?? _progress
        }
        set {
            _progress = newValue
        }
    }

    private(set) var assetId: String?
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
            _asset = newValue
        }
    }

    var isReady: Bool {
        return (asset?.isReady ?? false)
            && !(asset?.isUploaded ?? false)
            && (asset?.space?.uploadAllowed ?? false)
    }

    var state: PKDownloadButtonState {
        if paused {
            return .startDownload
        }

        if progress >= 1 {
            return .downloaded
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
        _progress = decoder.decodeDouble(forKey: "progress")
        paused = decoder.decodeBool(forKey: "paused")
        tries = decoder.decodeInteger(forKey: "tries")
        lastTry = decoder.decodeObject(forKey: "lastTry") as? Date
        error = decoder.decodeObject(forKey: "error") as? String
        assetId = decoder.decodeObject(forKey: "assetId") as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(order, forKey: "order")
        coder.encode(progress, forKey: "progress")
        coder.encode(paused, forKey: "paused")
        coder.encode(tries, forKey: "tries")
        coder.encode(lastTry, forKey: "lastTry")
        coder.encode(error, forKey: "error")
        coder.encode(assetId, forKey: "assetId")
    }


    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        return NSKeyedUnarchiver.unarchiveObject(with:
            NSKeyedArchiver.archivedData(withRootObject: self))!
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), order=\(order), "
            + "progress=\(progress), paused=\(paused), tries=\(tries), "
            + "lastTry=\(lastTry?.debugDescription ?? "nil"), error=\(error ?? "nil"), "
            + "assetId=\(assetId ?? "nil"), asset=\(asset?.description ?? "nil")]"
    }


    // MARK: YapDatabaseRelationshipNode

    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        if let assetId = assetId {
            return [YapDatabaseRelationshipEdge(
                name: "asset", destinationKey: assetId, collection: Asset.collection,
                nodeDeleteRules: .deleteSourceIfDestinationDeleted)]
        }

        return nil
    }


    // MARK: Public Methods

    func cancel() {
        if let liveProgress = liveProgress {
            liveProgress.cancel()
            self.liveProgress = nil
            progress = 0
        }
    }

    func hasProgressChanged() -> Bool {
        return _progress != liveProgress?.fractionCompleted ?? 0
    }

    /**
     Asynchronously deletes this upload and its asset from the database
     and reorders the other uploads, if necessary.

     - parameter callback: Optional callback is called asynchronously on main queue after removal.
     */
    func remove(_ callback: (() -> Void)? = nil) {
        Db.writeConn?.asyncReadWrite { transaction in
            transaction.removeObject(forKey: self.id, inCollection: Upload.collection)

            if let assetId = self.assetId {
                transaction.removeObject(forKey: assetId, inCollection: Asset.collection)
            }

            // Reorder uploads.
            (transaction.ext(UploadsView.name) as? YapDatabaseViewTransaction)?
                .iterateKeysAndObjects(inGroup: UploadsView.groups[0])
                { collection, key, object, index, stop in
                    if let upload = object as? Upload,
                        upload.order != index {

                        upload.order = index

                        transaction.replace(upload, forKey: upload.id, inCollection: collection)
                    }
            }

            if let callback = callback {
                DispatchQueue.main.async(execute: callback)
            }
        }
    }
}

//
//  Upload.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class Upload: NSObject, Item, YapDatabaseRelationshipNode {

    enum State: CustomStringConvertible {
        case paused
        case pending
        case uploading
        case uploaded

        var description: String {
            switch self {
            case .paused:
                return "paused"
            case .pending:
                return "pending"
            case .uploading:
                return "uploading"
            case .uploaded:
                return "uploaded"
            }
        }
    }

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

    func preheat(_ tx: YapDatabaseReadTransaction, deep: Bool = true) {
        if _asset?.id != assetId {
            _asset = tx.object(for: assetId)
        }

        if deep {
            _asset?.preheat(tx, deep: deep)
        }
    }


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
            if _asset == nil {
                _asset = Db.bgRwConn?.object(for: assetId)
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

    var state: State {
        if paused {
            return .paused
        }

        if progress >= 1 {
            return .uploaded
        }

        if progress > 0 {
            return .uploading
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


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject(of: NSString.self, forKey: "id") as? String ?? UUID().uuidString
        order = decoder.decodeInteger(forKey: "order")
        _progress = decoder.decodeDouble(forKey: "progress")
        paused = decoder.decodeBool(forKey: "paused")
        tries = decoder.decodeInteger(forKey: "tries")
        lastTry = decoder.decodeObject(of: NSDate.self, forKey: "lastTry") as? Date
        error = decoder.decodeObject(of: NSString.self, forKey: "error") as? String
        assetId = decoder.decodeObject(of: NSString.self, forKey: "assetId") as? String
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
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
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
        Db.writeConn?.asyncReadWrite { tx in
            tx.remove(self)

            if let assetId = self.assetId,
               let asset: Asset = tx.object(for: assetId)
            {
                asset.remove(tx)
            }

            // Reorder uploads.
            tx.iterate(group: UploadsView.groups.first, in: UploadsView.name) 
            { (collection, key, upload: Upload, index, stop) in
                if upload.order != index {
                    upload.order = index

                    tx.replace(upload)
                }
            }

            if let callback = callback {
                DispatchQueue.main.async(execute: callback)
            }
        }
    }
}

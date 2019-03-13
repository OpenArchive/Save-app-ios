//
//  Upload.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class Upload: NSObject, Item {

    // MARK: Item

    static let collection  = "uploads"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Upload", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Upload")
    }

    func compare(_ rhs: Upload) -> ComparisonResult {
        return rhs.id.compare(id)
    }

    var id: String


    // MARK: Upload

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

    var thumbnail: UIImage? {
        return asset?.getThumbnail()
    }

    var filename: String {
        return asset!.filename
    }

    init(asset: Asset) {
        id = UUID().uuidString
        assetId = asset.id
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject(forKey: "id") as? String ?? UUID().uuidString
        assetId = decoder.decodeObject(forKey: "assetId") as? String
        paused = decoder.decodeObject(forKey: "paused") as? Bool ?? false
        progress = decoder.decodeObject(forKey: "progress") as? Double ?? 0
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(assetId, forKey: "assetId")
        coder.encode(paused, forKey: "paused")
        coder.encode(progress, forKey: "progress")
    }

    func start() {

        if let asset = asset {
            paused = false

            asset.space?.upload(asset, progress: { asset, progress in

                self.progress = progress.fractionCompleted

                Db.bgRwConn?.asyncReadWrite { transaction in
                    transaction.setObject(self, forKey: self.id, inCollection: Upload.collection)
                }
            }, done: { asset in
                Db.bgRwConn?.asyncReadWrite { transaction in
                    transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
                    transaction.setObject(self, forKey: self.id, inCollection: Upload.collection)
                }
            })
        }
    }

    func pause() {
        paused = true

        // TODO: Kill ongoing upload, if any.
    }
}

//
//  Collection.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 31.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A `Collection` is the aggregation of one or more `Assets` which were edited
 and uploaded at the same time.

 A `Collection` belongs to exactly one `Project`. It can't live without one.

 Each `Project` only ever has one open `Collection` at a time. All `Assets` the
 user adds to a `Project` become member of the currently open `Collection`.

 If there currently is no open `Collection`, a new one shall be created.
 */
class Collection: NSObject, Item, YapDatabaseRelationshipNode {

    // MARK: Item

    static let collection  = "collections"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Collection", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Collection")
    }

    func compare(_ rhs: Collection) -> ComparisonResult {
        return (closed ?? created).compare(rhs.closed ?? rhs.created)
    }

    var id: String


    // MARK: Collection

    private(set) var projectId: String

    private var _project: Project?
    var project: Project {
        get {
            if _project == nil {
                Db.bgRwConn?.read { transaction in
                    _project = transaction.object(forKey: self.projectId, inCollection: Project.collection) as? Project
                }
            }

            return _project!
        }
        set {
            projectId = newValue.id
            _project = newValue
        }
    }

    var created: Date
    private(set) var closed: Date?
    private(set) var uploaded: Date?

    var name: String? {
        return Formatters.timestamp.string(from: created)
    }

    var isOpen: Bool {
        return closed == nil && uploaded == nil
    }

    /**
     List of assets, which belong to this collection.

     This is temporary and can only be used for buffering.

     The responsibility is on you to keep this in sync!
    */
    var assets = [Asset]()

    var uploadedAssetsCount: Int {
        get {
            var uploaded = 0

            for asset in assets {
                if asset.isUploaded {
                    uploaded += 1
                }
            }

            return uploaded
        }
    }

    var waitingAssetsCount: Int {
        get {
            var waiting = 0

            for asset in assets {
                if !asset.isUploaded {
                    waiting += 1
                }
            }

            return waiting
        }
    }

    class func get(byId id: String?, conn: YapDatabaseConnection? = Db.bgRwConn) -> Collection? {
        var collection: Collection?

        if let id = id {
            conn?.read { transaction in
                collection = transaction.object(forKey: id,
                    inCollection: Collection.collection) as? Collection
            }
        }

        return collection
    }

    init(_ project: Project) {
        id = UUID().uuidString
        projectId = project.id
        created = Date()
    }


    // MARK: NSCoding

    required init?(coder: NSCoder) {
        id = coder.decodeObject(forKey: "id") as? String ?? UUID().uuidString
        projectId = coder.decodeObject(forKey: "projectId") as! String
        created = coder.decodeObject(forKey: "created") as? Date ?? Date()
        closed = coder.decodeObject(forKey: "closed") as? Date
        uploaded = coder.decodeObject(forKey: "uploaded") as? Date
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(projectId, forKey: "projectId")
        coder.encode(created, forKey: "created")
        coder.encode(closed, forKey: "closed")
        coder.encode(uploaded, forKey: "uploaded")
    }


    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        return NSKeyedUnarchiver.unarchiveObject(with:
            NSKeyedArchiver.archivedData(withRootObject: self))!
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "projectId=\(projectId), created=\(created), "
            + "closed=\(String(describing: closed)), "
            + "uploaded=\(String(describing: uploaded))]"
    }


    // MARK: YapDatabaseRelationshipNode

    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        return [YapDatabaseRelationshipEdge(
            name: "project", destinationKey: projectId, collection: Project.collection,
            nodeDeleteRules: .deleteSourceIfDestinationDeleted)]
    }


    // MARK: Public Methods

    func close() {
        if closed == nil {
            closed = Date()
        }
    }

    func setUploadedNow() {
        uploaded = Date()
    }
}

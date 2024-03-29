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
        (closed ?? created).compare(rhs.closed ?? rhs.created)
    }

    var id: String

    func preheat(_ tx: YapDatabaseReadTransaction, deep: Bool = true) {
        if _project?.id != projectId {
            _project = tx.object(for: projectId)
        }

        if deep {
            _project?.preheat(tx, deep: deep)
        }
    }


    // MARK: Collection

    private(set) var projectId: String

    private var _project: Project?
    var project: Project {
        get {
            if _project == nil {
                _project = Db.bgRwConn?.object(for: projectId)
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
        Formatters.timestamp.string(from: created)
    }

    var isOpen: Bool {
        closed == nil && uploaded == nil
    }

    /**
     List of assets, which belong to this collection.

     This is temporary and can only be used for buffering.

     The responsibility is on you to keep this in sync!
    */
    var assets = [Asset]()

    var uploadedAssetsCount: Int {
        assets.reduce(0) { $0 + ($1.isUploaded ? 1 : 0) }
    }

    var waitingAssetsCount: Int {
        assets.reduce(0) { $0 + ($1.isUploaded ? 0 : 1) }
    }


    init(_ project: Project) {
        id = UUID().uuidString
        projectId = project.id
        created = Date()
    }


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true

    required init?(coder: NSCoder) {
        id = coder.decodeObject(of: NSString.self, forKey: "id") as? String ?? UUID().uuidString
        projectId = coder.decodeObject(of: NSString.self, forKey: "projectId")! as String
        created = coder.decodeObject(of: NSDate.self, forKey: "created") as? Date ?? Date()
        closed = coder.decodeObject(of: NSDate.self, forKey: "closed") as? Date
        uploaded = coder.decodeObject(of: NSDate.self, forKey: "uploaded") as? Date
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
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
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

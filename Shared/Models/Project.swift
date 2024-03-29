//
//  Project.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

/**
 A `Project` is the aggregation of none, one or more `Collections`.

 On WebDAV servers, it also represents a folder with the same `name`.

 A `Project` belongs to none or one `Space`. If it becomes disconnected,
 the `url`s of its containing `Assets` shall become invalid.

 If the user wants to add `Assets` to the app, there needs to be at least one
 `Project`. If there are more than one, the user needs to choose one.
 */
class Project: NSObject, Item, YapDatabaseRelationshipNode {

    // MARK: Item

    static let collection  = "projects"

    static func fixArchiverName() {
        NSKeyedArchiver.setClassName("Project", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "Project")
    }

    func compare(_ rhs: Project) -> ComparisonResult {
        return rhs.created.compare(created)
    }

    var id: String

    func preheat(_ tx: YapDatabaseReadTransaction, deep: Bool = true) {
        if _space?.id != spaceId {
            _space = tx.object(for: spaceId, in: Space.collection)
        }

        if deep {
            _space?.preheat(tx, deep: deep)
        }
    }


    // MARK: Project

    /**
     Helper method to ensure a proper project name in case of non-optionality.

     - parameter project: A `Project` object or `nil`.
     - returns: The given project's name or a default one.
    */
    class func getName(_ project: Project?) -> String {
        return project?.name ?? NSLocalizedString("Unnamed Project", comment: "")
    }

    var name: String?
    var created: Date
    var license: String?
    var active = true

    private(set) var spaceId: String?

    private var _space: Space?
    var space: Space? {
        get {
            if _space == nil {
                _space = Db.bgRwConn?.object(for: spaceId, in: Space.collection)
            }

            return _space
        }
        set {
            spaceId = newValue?.id
            _space = newValue
        }
    }

    private var collectionId: String?

    var currentCollection: Collection {
        var collection: Collection? = Db.bgRwConn?.object(for: collectionId)

        if !(collection?.isOpen ?? false) {
            collection = Collection(self)
            collectionId = collection?.id

            Db.writeConn?.asyncReadWrite { tx in
                tx.setObject(collection!)
                tx.setObject(self)
            }
        }

        return collection!
    }

    init(name: String? = nil, space: Space? = nil) {
        id = UUID().uuidString
        created = Date()
        self.name = name
        self.spaceId = space?.id
        self.license = space?.license
    }


    // MARK: NSSecureCoding

    static var supportsSecureCoding = true

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject(of: NSString.self, forKey: "id") as? String ?? UUID().uuidString
        created = decoder.decodeObject(of: NSDate.self, forKey: "created") as? Date ?? Date()
        name = decoder.decodeObject(of: NSString.self, forKey: "name") as? String
        license = decoder.decodeObject(of: NSString.self, forKey: "license") as? String
        active = decoder.decodeBool(forKey: "active")
        spaceId = decoder.decodeObject(of: NSString.self, forKey: "spaceId") as? String
        collectionId = decoder.decodeObject(of: NSString.self, forKey: "collectionId") as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(created, forKey: "created")
        coder.encode(name, forKey: "name")
        coder.encode(license, forKey: "license")
        coder.encode(active, forKey: "active")
        coder.encode(spaceId, forKey: "spaceId")
        coder.encode(collectionId, forKey: "collectionId")
    }


    // MARK: NSCopying

    func copy(with zone: NSZone? = nil) -> Any {
        return (try! NSKeyedUnarchiver.unarchivedObject(
            ofClass: type(of: self),
            from: try! NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)))!
    }


    // MARK: Equatable

    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "created=\(created), name=\(name ?? "nil"), license=\(license ?? "nil"), "
            + "active=\(active), spaceId=\(spaceId ?? "nil"), "
            + "collectionId=\(collectionId ?? "nil")]"
    }


    // MARK: YapDatabaseRelationshipNode

    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let id = spaceId {
            edges.append(YapDatabaseRelationshipEdge(
                name: "space", destinationKey: id, collection: Space.collection,
                nodeDeleteRules: .deleteSourceIfDestinationDeleted))
        }

        if let id = collectionId {
            edges.append(YapDatabaseRelationshipEdge(
                name: "collection", destinationKey: id, collection: Collection.collection,
                nodeDeleteRules: .notifyIfDestinationDeleted))
        }

        return edges
    }

    func yapDatabaseRelationshipEdgeDeleted(_ edge: YapDatabaseRelationshipEdge,
                                            with reason: YDB_NotifyReason) -> Any? {
        if edge.name == "space" {
            if let copy = self.copy() as? Project {
                copy.spaceId = nil

                return copy
            }
        }
        if edge.name == "collection" {
            if let copy = self.copy() as? Project {
                copy.collectionId = nil

                return copy
            }
        }

        return nil
    }
}

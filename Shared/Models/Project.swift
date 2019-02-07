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
        return (name ?? "").compare(rhs.name ?? "")
    }

    var id: String


    // MARK: Project

    var name: String?

    private(set) var spaceId: String?

    var space: Space? {
        get {
            var space: Space?

            if let id = spaceId {
                Db.bgRwConn?.read { transaction in
                    space = transaction.object(forKey: id, inCollection: Space.collection) as? Space
                }
            }

            return space
        }
        set {
            spaceId = newValue?.id
        }
    }

    private var collectionId: String?

    var currentCollection: Collection {
        var collection: Collection?

        if let id = collectionId {
            Db.bgRwConn?.read { transaction in
                collection = transaction.object(forKey: id, inCollection: Collection.collection) as? Collection
            }
        }

        if !(collection?.isOpen ?? false) {
            collection = Collection(self)
            collectionId = collection?.id

            Db.writeConn?.readWrite { transaction in
                transaction.setObject(collection, forKey: collection!.id, inCollection: Collection.collection)
                transaction.setObject(self, forKey: self.id, inCollection: Project.collection)
            }
        }

        return collection!
    }

    init(name: String? = nil, space: Space? = nil) {
        id = UUID().uuidString
        self.name = name
        self.spaceId = space?.id
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        name = decoder.decodeObject() as? String
        spaceId = decoder.decodeObject() as? String
        collectionId = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
        coder.encode(spaceId)
        coder.encode(collectionId)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), "
            + "name=\(name ?? "nil"), spaceId=\(spaceId ?? "nil"), "
            + "collectionId=\(collectionId ?? "nil")]"
    }


    // MARK: YapDatabaseRelationshipNode

    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        var edges = [YapDatabaseRelationshipEdge]()

        if let id = spaceId {
            edges.append(YapDatabaseRelationshipEdge(
                name: "space", destinationKey: id, collection: Space.collection,
                nodeDeleteRules: .notifyIfDestinationDeleted))
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

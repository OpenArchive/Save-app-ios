//
//  Project.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

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


    // MARK: Project

    var id: String

    var name: String?

    private(set) var spaceId: String?

    var space: Space? {
        get {
            var space: Space?

            if let spaceId = spaceId {
                Db.newConnection()?.read { transaction in
                    space = transaction.object(forKey: spaceId, inCollection: Space.collection) as? Space
                }
            }

            return space
        }
        set {
            spaceId = newValue?.id
        }
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
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
        coder.encode(spaceId)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), name=\(name ?? "nil"), spaceId=\(spaceId ?? "nil")]"
    }


    // MARK: YapDatabaseRelationshipNode

    func yapDatabaseRelationshipEdges() -> [YapDatabaseRelationshipEdge]? {
        if let spaceId = spaceId {
            return [YapDatabaseRelationshipEdge(
                name: "space", destinationKey: spaceId, collection: Space.collection,
                nodeDeleteRules: .notifyIfSourceDeleted)]
        }

        return nil
    }

    func yapDatabaseRelationshipEdgeDeleted(_ edge: YapDatabaseRelationshipEdge,
                                            with reason: YDB_NotifyReason) -> Any? {
        if edge.name == "space" {
            if let copy = self.copy() as? Project {
                copy.spaceId = nil

                return copy
            }
        }

        return nil
    }
}

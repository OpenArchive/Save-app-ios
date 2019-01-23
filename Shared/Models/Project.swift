//
//  Project.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 22.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class Project: NSObject, Item {

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


    init(_ name: String? = nil) {
        id = UUID().uuidString
        self.name = name
    }


    // MARK: NSCoding

    required init?(coder decoder: NSCoder) {
        id = decoder.decodeObject() as? String ?? UUID().uuidString
        name = decoder.decodeObject() as? String
    }

    func encode(with coder: NSCoder) {
        coder.encode(id)
        coder.encode(name)
    }


    // MARK: NSObject

    override var description: String {
        return "\(String(describing: type(of: self))): [id=\(id), name=\(name ?? "nil")]"
    }
}

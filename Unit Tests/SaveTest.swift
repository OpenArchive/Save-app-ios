//
//  SaveTest.swift
//  Save UI Tests
//
//  Created by Ryan Jennings on 2025-06-27.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import XCTest

@testable import Save_Test

class SaveTest: XCTestCase {
    
    static let images = ["IMG_4014", "IMG_3201", "IMG_1491",
                                 "IMG_1252", "IMG_1508", "IMG_1291" ]
    
    let server = Save_Test.testServer
    
    struct Data {
        var project: Project
        var space: Space
        var collection: Collection
        
        init(project: Project, space: Space, collection: Collection) {
            self.project = project
            self.space = space
            self.collection = collection
        }
    }
    
    func preload(space: Space) -> Data {
        
        space.url = URL(string: "http://localhost:8080/test/server")!
        
        let project = Project(space: space)
        project.name = "Test Project"
        
        Db.writeConn?.readWrite({ tx in
            tx.removeAllObjectsInAllCollections()
            tx.setObject(space, forKey: space.id, inCollection: Space.collection)
            
            SelectedSpace.store(tx)
            
            tx.setObject(project)
        })
        
        let collection = project.currentCollection
        
        for image in SaveTest.images {
            let asset = AssetFactory.create(fromAssets: image, collection)
            
            collection.assets.append(asset)
            
            _ = Asset.updateSync(assets: [asset]) {
                $0.filename = "\(image).JPG"
                $0.location = "10405 Berlin\nGermany"
            }
        }
        
        return Data(project: project, space: space, collection: collection)
    }
}


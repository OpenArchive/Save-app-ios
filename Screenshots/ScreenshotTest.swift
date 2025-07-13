//
//  Screenshots.swift
//  Screenshots
//
//  Created by Benjamin Erhart on 18.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import XCTest

class ScreenshotTest: XCTestCase {
    
    private let app = XCUIApplication(bundleIdentifier: Bundle.main.infoDictionary?["OA_SCS_BUNDLE_ID"] as? String ?? "org.open-archive.save")
    
    @MainActor
    override func setUp() {
        super.setUp()
        app.launch()
    }
    
    @MainActor
    override func tearDown() {
        super.tearDown()
        app.terminate()
    }
    
    @MainActor
    func testTakeScreenshots() {
        let springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        setupSnapshot(app)
    
        app.activate()
        
        snapshot("01MainScene")
        
        app.otherElements.element(boundBy: 30).tap()
        
        snapshot("02EditAsset")
        
        app/*@START_MENU_TOKEN@*/.buttons["Back"]/*[[".navigationBars.buttons[\"Back\"]",".buttons[\"Back\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        
        let addButton = app/*@START_MENU_TOKEN@*/.buttons["addButton"]/*[[".otherElements",".buttons[\"add\"]",".buttons[\"addButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        addButton.tap()
        
        let permission = springboardApp/*@START_MENU_TOKEN@*/.buttons["Allow Full Access"]/*[[".otherElements.buttons[\"Allow Full Access\"]",".buttons[\"Allow Full Access\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        if permission.exists {
            permission.tap()
        }
        
        let disclaimer = app.buttons["Ok"]
        if disclaimer.exists {
            disclaimer.tap()
        }
        
        if addButton.isHittable {
            addButton.tap()
        }
        
        snapshot("03UploadAssets")
        
        let elementsQuery = app.otherElements
        elementsQuery.element(boundBy: 25).tap()
        elementsQuery.element(boundBy: 24).tap()
        app.buttons["Done"].tap()
        app.buttons["Back"].tap()
        
        app/*@START_MENU_TOKEN@*/.buttons["btSettings"]/*[[".buttons.containing(.staticText, identifier: \"Settings\").firstMatch",".otherElements",".buttons[\"Settings\"]",".buttons[\"btSettings\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        snapshot("04Settings")
        
        app/*@START_MENU_TOKEN@*/.buttons["My Media"]/*[[".buttons.containing(.staticText, identifier: \"My Media\").firstMatch",".otherElements.buttons[\"My Media\"]",".buttons[\"My Media\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.buttons["btMenu"]/*[[".navigationBars",".buttons.firstMatch",".buttons[\"menu icon\"]",".buttons[\"btMenu\"]"],[[[-1,3],[-1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        snapshot("05Menu")
        
        app/*@START_MENU_TOKEN@*/.staticTexts["Tunis 2019"]/*[[".cells.staticTexts[\"Tunis 2019\"]",".staticTexts[\"Tunis 2019\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        snapshot("06NewFolder")
        app/*@START_MENU_TOKEN@*/.buttons["editButton"]/*[[".otherElements",".buttons[\"edit menu\"]",".buttons[\"editButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
    }
}

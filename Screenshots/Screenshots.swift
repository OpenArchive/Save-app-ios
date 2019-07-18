//
//  Screenshots.swift
//  Screenshots
//
//  Created by Benjamin Erhart on 18.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import XCTest

class Screenshots: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        let app = XCUIApplication()
        app.launchArguments.append("--UITests")
        setupSnapshot(app)
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testWalkthrough() {
        let app = XCUIApplication()
        let tablesQuery = app.tables

        // Forward through Onboarding scenes.
        app/*@START_MENU_TOKEN@*/.staticTexts["btGetStarted"]/*[[".staticTexts[\"Get Started\"]",".staticTexts[\"btGetStarted\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        let element = app.otherElements["container"]
        element.tap()
        element.tap()
        element.tap()

        app/*@START_MENU_TOKEN@*/.buttons["btDone"]/*[[".buttons[\"Done\"]",".buttons[\"btDone\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()


        // Create new Space
        app.tables.cells["cellPrivateServer"].tap()

        tablesQuery.textFields["tfServerUrl"].tap()
        tablesQuery.textFields["tfServerUrl"].typeText("https://nextcloud.example.com/remote.php/webdav/")

        tablesQuery/*@START_MENU_TOKEN@*/.textFields["tfUsername"]/*[[".cells",".textFields[\"Required\"]",".textFields[\"tfUsername\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.textFields["tfUsername"]/*[[".cells",".textFields[\"Required\"]",".textFields[\"tfUsername\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.typeText("username")

        tablesQuery/*@START_MENU_TOKEN@*/.secureTextFields["tfPassword"]/*[[".cells",".secureTextFields[\"Required\"]",".secureTextFields[\"tfPassword\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.secureTextFields["tfPassword"]/*[[".cells",".secureTextFields[\"Required\"]",".secureTextFields[\"tfPassword\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.typeText("password")

        snapshot("01CreateSpace")

        app/*@START_MENU_TOKEN@*/.buttons["btConnect"]/*[[".buttons[\"Done\"]",".buttons[\"btConnect\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()


        // Create new Space
        app.tables.cells["cellCreateNewProject"].tap()

        tablesQuery.textFields["tfProjectName"].tap()
        tablesQuery.textFields["tfProjectName"].typeText("Test")

        app.buttons["btDone"].tap()

        snapshot("02Main")
    }

}

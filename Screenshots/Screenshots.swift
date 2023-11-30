//
//  Screenshots.swift
//  Screenshots
//
//  Created by Benjamin Erhart on 18.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import XCTest

class Screenshots: XCTestCase {

    private static let startupTimeout: TimeInterval = 10

    @MainActor 
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor 
    func testWalkthrough() {
        let app = XCUIApplication()

        var match = app.collectionViews.children(matching: .cell).firstMatch

        XCTAssert(match.waitForExistence(timeout: Self.startupTimeout),
                  "App didn't start up within \(Self.startupTimeout) seconds!")

        snapshot("01MainScene")

        match.tap()

        snapshot("02EditAsset")

        app.navigationBars.firstMatch.buttons["btUpload"].tap()

        app.buttons["btManageUploads"].tap()

        snapshot("03UploadAssets")

        if UIDevice.current.userInterfaceIdiom == .pad {
            app.otherElements["PopoverDismissRegion"].tap()
        }
        else {
            app.navigationBars.firstMatch.buttons.firstMatch.tap()
        }

        app.buttons["btSettings"].tap()
        app.buttons["btFolder"].tap()
        app.tables.staticTexts["Berlin 2018"].tap()

        snapshot("04EditProject")

        app.navigationBars.firstMatch.buttons.firstMatch.tap()

        app.navigationBars.firstMatch.buttons.firstMatch.tap()

        app.buttons["btMenu"].tap()

        app.otherElements["viewHeader"].tap()

        app.cells["cellAddAccount"].tap()

        match = app.otherElements["viewPrivateServer"]

        // Don't tap too early, otherwise nothing will happen.
        XCTAssert(match.waitForExistence(timeout: Self.startupTimeout))

        match.tap()


        snapshot("05CreateSpace")

        // Back to main scene.
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
    }
}

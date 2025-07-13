//
//  Test.swift
//  Screenshots
//
//  Created by Ryan Jennings on 2025-06-27.
//  Copyright © 2025 Open Archive. All rights reserved.
//

import XCTest
@testable import Save_Test

class IAUploadTest: SaveTest {
    
    private var data: Data?
    private let proxyServer = TestServer(port: 8118)
    
    override func setUp() async throws {
        try await super.setUp()
        
        let space = IaSpace(accessKey: "abc", secretKey: "xyz", baseUrl: "http://localhost:8080")
        
        data = preload(space: space)
        
        try await proxyServer.start()
    }
    
    override func tearDown() async throws  {
        try await super.tearDown()
        await proxyServer.stop()
        data = nil
    }
    
    func testIAConduitHasProxyWhenEnabled() async throws {
        
        Settings.useOrbot = true
        
        let asset = data!.collection.assets.first!
        let upload = Upload(order: 1, asset: asset)

        Db.writeConn?.setObject(asset)
        Db.writeConn?.setObject(upload)
        
        let request = try await proxyServer.waitForRequest()
        
        let file = request.url.components(separatedBy: "/").last
        
        XCTAssertEqual(request.method, "PUT", "Test server should receive a PUT proxy request")
        XCTAssertEqual(file, asset.filename, "Test server should has the asset url")
    }
    
    func testIAConduitWithoutProxy() async throws {
        Settings.useOrbot = false
        
        let asset = data!.collection.assets.first!
        let upload = Upload(order: 1, asset: asset)

        Db.writeConn?.setObject(asset)
        Db.writeConn?.setObject(upload)
        
        let request = try await server.waitForRequest()
        
        let file = request.url.components(separatedBy: "/").last
        
        XCTAssertEqual(request.method, "PUT", "Test server should receive a PUT proxy request")
        XCTAssertEqual(file, asset.filename, "Test server should has the asset url")
    }
}

//
//  AppDelegate.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: AppDelegateBase {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
        // Disable animations to avoid timing issues.
        UIView.setAnimationsEnabled(false)

        _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        Fixtures.prepare()
        
        Task {
            do {
                try await testServer.start()
            } catch {
                print("unable to start test server \(error)")
            }
        }

        return true
    }
}

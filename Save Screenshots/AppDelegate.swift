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

        _ = super.application(application, didFinishLaunchingWithOptions: launchOptions)

        Screenshots.prepare()

        return true
    }
}

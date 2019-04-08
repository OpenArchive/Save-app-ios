//
//  BackgroundUploadManager.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.04.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BackgroundUploadManager: UploadManager {

    static let shared = BackgroundUploadManager()

    private var schedule: Timer?

    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    private convenience init() {
        self.init(nil)

        progressTimer.resume()

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModifiedExternally, object: nil)

        nc.addObserver(self, selector: #selector(pause),
                       name: .uploadManagerPause, object: nil)

        nc.addObserver(self, selector: #selector(unpause),
                       name: .uploadManagerUnpause, object: nil)

        nc.addObserver(self, selector: #selector(reachabilityChanged),
                       name: .reachabilityChanged, object: reachability)

        try? reachability?.startNotifier()

        schedule = Timer(fireAt: Date().addingTimeInterval(1), interval: 60,
                         target: self, selector: #selector(self.uploadNext),
                         userInfo: nil, repeats: true)

        // Schedule a timer, which calls #uploadNext every 60 seconds beginning
        // in 1 second.
        RunLoop.main.add(schedule!, forMode: .common)

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        debug("#endBackgroundTask")

        schedule?.invalidate()

        NotificationCenter.default.removeObserver(self)

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

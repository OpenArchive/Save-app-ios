//
//  BlurredSnapshot.swift
//  Save
//
//  Created by Benjamin Erhart on 17.01.24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class BlurredSnapshot: NSObject {

    private static var resignActiveCover: UIView?
    private static var captureCover: UIView?

    /**
     Creates a blurred snapshot over the current window content.
     Use this to block screenshots and recent apps preview.
     */
    @objc class func create(_ window: UIWindow?) {
        guard resignActiveCover == nil, let window else { return }

        // Take a snapshot of current screen
        if let snapshot = window.snapshotView(afterScreenUpdates: false) {
            resignActiveCover = snapshot

            // Add a blur effect to the snapshot
            let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
            blurEffectView.frame = snapshot.bounds
            snapshot.addSubview(blurEffectView)

            // Add the blurred snapshot on top of the window
            window.addSubview(snapshot)
        }

    }

    /**
     Remove blurred snapshot again when coming back from background.

     Call this from AppDelegate#applicationDidBecomeActive:
     */
    @objc class func remove() {
        resignActiveCover?.removeFromSuperview()
        resignActiveCover = nil
    }

    /**
     Lightweight full-window blur while the screen is being mirrored or recorded.
     Uses no bitmap snapshot, so it is cheaper than `create` and suitable for long capture sessions.
     */
    class func setCapturePrivacyEnabled(_ enabled: Bool, window: UIWindow?) {
        if !enabled {
            captureCover?.removeFromSuperview()
            captureCover = nil
            return
        }
        guard captureCover == nil, let window else { return }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blur.frame = window.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(blur)
        captureCover = blur
    }
}

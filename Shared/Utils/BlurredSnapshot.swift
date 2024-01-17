//
//  BlurredSnapshot.swift
//  Save
//
//  Created by Benjamin Erhart on 17.01.24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class BlurredSnapshot: NSObject {

	private static var view: UIView?

	/**
	Blur current window content to increase privacy when in background.

	Call this from AppDelegate#applicationWillResignActive:
	*/
	@objc class func create(_ window: UIWindow?) {
		// Blur current content to increase privacy when in background.
		if view == nil,
			let window = window,
			let view = window.snapshotView(afterScreenUpdates: false)
		{
			self.view = view

			let vev = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
			vev.frame = view.bounds

			view.addSubview(vev)
			window.addSubview(view)
		}
	}

	/**
	Remove blurred snapshot again when coming back from background.

	Call this from AppDelegate#applicationDidBecomeActive:
	*/
	@objc class func remove() {
		view?.removeFromSuperview()
		view = nil
	}
}

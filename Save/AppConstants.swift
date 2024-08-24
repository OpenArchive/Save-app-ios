//
//  Created by Richard Puckett on 5/23/24.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

typealias AffirmativeAnswer = (_ affirm: Bool) -> Void

struct AppMessage {
    public static let titleForUserError = "Oops"
    public static let titleForAppError = "Sorry"
    public static let titleForInfo = "Hey, there"
    public static let titleForGoodNews = "Yay!"
}

struct AppStyle {
    public static let minSwipeVelocity = 500.0
    public static let animationDuration = 0.25
    public static let appCornerRadius = 7.0
    public static let borderWidth = 0.25
    public static let mainButtonHeight = 60.0
    public static var hapticIntensity = 0.50
    
    static let appTint = UIColor.white
    static let dialogBackgroundColor = UIColor(hexString: "#16161D")! // Eigengrau: #16161D
    public static let borderColor = UIColor(named: "border_color")!
    public static let translucentWhiteColor = UIColor.white.withAlphaComponent(0.75)
    
    public static let modalPresentationStyle = UIModalPresentationStyle.overFullScreen
}

public enum NervousAlertDuration: Double {
    case flash      = 0.5
    case fast       = 1.0
    case short      = 2
    case long       = 3.5
}

public enum AppAnalytic: String {
    case connectionNotFound
}

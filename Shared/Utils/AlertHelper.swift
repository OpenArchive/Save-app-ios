//
//  AlertHelper.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 2021-11-29.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

public class AlertHelper {

    public typealias ActionHandler = () -> Void

    /**
     Presents the custom SwiftUI alert via `UIHostingController`.

     if `actions` is omitted, it will have one action of type `.default` labeled "OK".

     - parameter controller: The `UIViewController` to present on.
     - parameter message: The alert message. Optional.
     - parameter title: The alert title. Optional, defaults to localized "Error".
     - parameter actions: A list of actions. Optional, defaults to one localized "OK" default action.
     */
    public class func present(_ controller: UIViewController,
                              message: String? = nil,
                              title: String? = NSLocalizedString("Error", comment: ""),
                              actions: [AlertActionConfig]? = nil)
    {
        let actionConfigs = actions ?? [AlertActionConfig(title: NSLocalizedString("OK", comment: ""), isPrimary: true, handler: nil)]

        // Separate primary and secondary actions
        let primaryAction = actionConfigs.first(where: { $0.isPrimary }) ?? actionConfigs.first!
        let secondaryAction = actionConfigs.first(where: { !$0.isPrimary })

        let model = CustomAlertPresentationModel(
            title: title ?? "",
            message: message ?? "",
            primaryButtonTitle: primaryAction.title,
            primaryButtonAction: {
                primaryAction.handler?()
            },
            secondaryButtonTitle: secondaryAction?.title,
            secondaryButtonAction: secondaryAction != nil ? {
                secondaryAction?.handler?()
            } : nil,
            secondaryButtonIsOutlined: secondaryAction?.isDestructive == false,
            showCheckbox: false,
            iconImage: Image(systemName: "exclamationmark.triangle.fill"),
            iconTint: .yellow
        )

        HostedCustomAlertPresenter.present(from: controller, model: model)
    }

    /**
     - parameter title: The action's title. Optional, defaults to localized "OK".
     - parameter handler: The callback when the user tapped the action.
     - returns: A default alert action config.
     */
    public class func defaultAction(_ title: String? = NSLocalizedString("OK", comment: ""),
                                    handler: ActionHandler? = nil) -> AlertActionConfig
    {
        return AlertActionConfig(title: title ?? NSLocalizedString("OK", comment: ""), isPrimary: true, handler: handler)
    }

    /**
     - parameter title: The action's title. Optional, defaults to localized "Cancel".
     - parameter handler: The callback when the user tapped the action. Optional.
     - returns: A cancel alert action config.
     */
    public class func cancelAction(_ title: String? = NSLocalizedString("Cancel", comment: ""),
                                   handler: ActionHandler? = nil) -> AlertActionConfig
    {
        return AlertActionConfig(title: title ?? NSLocalizedString("Cancel", comment: ""), isPrimary: false, handler: handler)
    }

    /**
     - parameter title: The action's title.
     - parameter handler: The callback when the user tapped the action.
     - returns: A destructive alert action config.
     */
    public class func destructiveAction(_ title: String?, handler: ActionHandler? = nil) -> AlertActionConfig
    {
        return AlertActionConfig(title: title ?? "", isPrimary: false, isDestructive: true, handler: handler)
    }
}

public struct AlertActionConfig {
    let title: String
    let isPrimary: Bool
    let isDestructive: Bool
    let handler: AlertHelper.ActionHandler?

    init(title: String, isPrimary: Bool, isDestructive: Bool = false, handler: AlertHelper.ActionHandler? = nil) {
        self.title = title
        self.isPrimary = isPrimary
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

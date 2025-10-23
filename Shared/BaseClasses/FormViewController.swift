//
//  FormViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Eureka

/**
 Own base class of Eureka's FormViewController which adds our own base style:

 - UITableView.Style.plain instead of .grouped
 - White background
 - No trailing empty cells
 - Own special header
 */
class FormViewController: Eureka.FormViewController {

    lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()

    init() {
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func keyboardWillShow(_ notification: Notification) {
        // When showing inside a popover on iPad, the popover gets resized on
        // keyboard display, so we shall not do this inside the view.
        if popoverPresentationController != nil && UIDevice.current.userInterfaceIdiom == .pad {
            return
        }

        super.keyboardWillShow(notification)
    }

    // MARK: Actions

    @IBAction func dismiss(_ sender: Any? = nil) {
        if let nav = navigationController, navigationController?.viewControllers.first != self {
            nav.popViewController(animated: true)
        }
        else {
            dismiss(animated: true)
        }
    }
}

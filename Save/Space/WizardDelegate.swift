//
//  SpaceWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

protocol WizardDelegate: AnyObject {

    func back()

    func next(_ vc: UIViewController, pos: Int)

    func dismiss(success: Bool)
}

protocol WizardDelegatable: AnyObject {

    var delegate: WizardDelegate? { get set }
}

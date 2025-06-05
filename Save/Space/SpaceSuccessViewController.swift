//
//  SpaceSuccessViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 22.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceSuccessViewController: BaseViewController, WizardDelegatable {
    
    weak var delegate: WizardDelegate?
    
    var spaceName = ""
    
    
    @IBOutlet weak var titleLb: UILabel!
    
    @IBOutlet weak var doneBt: UIButton! {
        didSet {
            doneBt.setTitle(NSLocalizedString("Done", comment: ""))
            doneBt.titleLabel?.font = .montserrat(forTextStyle: .headline ,with: .traitUIOptimized)
            doneBt.cornerRadius = 10
            self.navigationItem.hidesBackButton = true
            self.title =  NSLocalizedString("Setup Complete", comment: "")
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLb.text = String(
            format: NSLocalizedString("You have successfully connected to %@!",
                                      comment: "Placeholder is a server type or name"),
            
            spaceName)
        
        titleLb.font = .montserrat(forTextStyle: .headline ,with: .traitUIOptimized)
    }
    
    @IBAction func done() {
    
        if let navigationController = self.navigationController {
            
            if let existingVC = navigationController.viewControllers.first(where: { $0 is MainViewController }) {
                
                navigationController.popToViewController(existingVC, animated: true)
            } else {
                
                let newVC = MainViewController()
                navigationController.pushViewController(newVC, animated: true)
            }
        }
    }
}

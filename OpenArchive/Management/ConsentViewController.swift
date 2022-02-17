//
//  ConsentViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.02.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit
import CleanInsightsSDK

class ConsentViewController: BaseViewController {

    class func new(_ completed: @escaping ConsentRequestUi.Complete) -> ConsentViewController {
        let vc = UIStoryboard.main.instantiateViewController(
            withIdentifier: "consentViewController") as! ConsentViewController

        vc.completed = completed

        return vc
    }


    @IBOutlet weak var okBt: UIButton! {
        didSet {
            okBt.setTitle("Yes".localize())
        }
    }

    @IBOutlet weak var declineBt: UIButton! {
        didSet {
            declineBt.setTitle("No thanks".localize())
        }
    }

    var completed: ConsentRequestUi.Complete?


    @IBAction func ok() {
        dismiss {
            self.completed?(true)
        }
    }

    @IBAction func decline() {
        dismiss {
            self.completed?(false)
        }
    }
}

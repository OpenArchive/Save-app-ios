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


    @IBOutlet weak var headerLb: UILabel! {
        didSet {
            headerLb.text = "Health checks help us understand why uploads fail.".localize()
        }
    }

    @IBOutlet weak var text1Lb: UILabel! {
        didSet {
            text1Lb.text = "Contribute your data to be part of the solution.".localize()
        }
    }

    @IBOutlet weak var text2Lb: UILabel! {
        didSet {
            text2Lb.text = "With your permission, we'll run a check each time you encounter an error while uploading.".localize()
        }
    }

    @IBOutlet weak var head2Lb: UILabel! {
        didSet {
            head2Lb.text = "Health checks capture".localize()
        }
    }

    @IBOutlet weak var point1Lb: UILabel! {
        didSet {
            point1Lb.text = "% Error description".localize(value: "–")
        }
    }

    @IBOutlet weak var point2Lb: UILabel! {
        didSet {
            point2Lb.text = "% Size and type of media".localize(value: "–")
        }
    }

    @IBOutlet weak var point3Lb: UILabel! {
        didSet {
            point3Lb.text = "% Number of retries".localize(value: "–")
        }
    }

    @IBOutlet weak var point4Lb: UILabel! {
        didSet {
            point4Lb.text = "% Network type".localize(value: "–")
        }
    }

    @IBOutlet weak var point5Lb: UILabel! {
        didSet {
            point5Lb.text = "% Locale".localize(value: "–")
        }
    }

    @IBOutlet weak var head3Lb: UILabel! {
        didSet {
            head3Lb.text = "Allow health checks?".localize()
        }
    }

    @IBOutlet weak var text3Lb: UILabel! {
        didSet {
            text3Lb.text = "By allowing health checks, you give permission for the app to securely send health check data to the % team.".localize(value: Bundle.main.displayName)
        }
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

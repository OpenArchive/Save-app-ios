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

    class func new(_ completed: @escaping ConsentRequestUi.CompleteCampaign) -> ConsentViewController {
        let vc = UIStoryboard.main.instantiateViewController(
            withIdentifier: "consentViewController") as! ConsentViewController

        vc.completed = completed

        return vc
    }


    @IBOutlet weak var headerLb: UILabel! {
        didSet {
            headerLb.font = headerLb.font.bold()
            headerLb.text = NSLocalizedString("Health checks help us understand why uploads fail.", comment: "")
        }
    }

    @IBOutlet weak var text1Lb: UILabel! {
        didSet {
            text1Lb.text = NSLocalizedString("Contribute your data to be part of the solution.", comment: "")
        }
    }

    @IBOutlet weak var text2Lb: UILabel! {
        didSet {
            text2Lb.text = NSLocalizedString("With your permission, we'll run a check each time you encounter an error while uploading.", comment: "")
        }
    }

    @IBOutlet weak var head2Lb: UILabel! {
        didSet {
            head2Lb.font = head2Lb.font.bold()
            head2Lb.text = NSLocalizedString("Health checks capture", comment: "")
        }
    }

    @IBOutlet weak var point1Lb: UILabel! {
        didSet {
            point1Lb.text = String(format: NSLocalizedString("%@ Error description", comment: ""), "–")
        }
    }

    @IBOutlet weak var point2Lb: UILabel! {
        didSet {
            point2Lb.text = String(format: NSLocalizedString("%@ Size and type of media", comment: ""), "–")
        }
    }

    @IBOutlet weak var point3Lb: UILabel! {
        didSet {
            point3Lb.text = String(format: NSLocalizedString("%@ Number of retries", comment: ""), "–")
        }
    }

    @IBOutlet weak var point4Lb: UILabel! {
        didSet {
            point4Lb.text = String(format: NSLocalizedString("%@ Network type", comment: ""), "–")
        }
    }

    @IBOutlet weak var point5Lb: UILabel! {
        didSet {
            point5Lb.text = String(format: NSLocalizedString("%@ Locale", comment: ""), "–")
        }
    }

    @IBOutlet weak var head3Lb: UILabel! {
        didSet {
            head3Lb.font = head3Lb.font.bold()
            head3Lb.text = NSLocalizedString("Allow health checks?", comment: "")
        }
    }

    @IBOutlet weak var text3Lb: UILabel! {
        didSet {
            text3Lb.text = String(format: NSLocalizedString("By allowing health checks, you give permission for the app to securely send health check data to the %@ team.", comment: ""), Bundle.main.displayName)
        }
    }

    @IBOutlet weak var okBt: UIButton! {
        didSet {
            okBt.setTitle(NSLocalizedString("OK", comment: ""))
        }
    }

    @IBOutlet weak var declineBt: UIButton! {
        didSet {
            declineBt.setTitle(NSLocalizedString("No thanks", comment: ""))
        }
    }

    var completed: ConsentRequestUi.CompleteCampaign?


    @IBAction func ok() {
        dismiss {
            self.completed?(true, nil)
        }
    }

    @IBAction func decline() {
        dismiss {
            self.completed?(false, nil)
        }
    }
}

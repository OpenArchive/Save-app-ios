//
//  AnalyticsCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.02.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import UIKit

protocol AnalyticsCellDelegate: AnyObject {

    func analyticsReload()

    func analyticsPresent(_ viewController: UIViewController)
}

class AnalyticsCell: BaseCell, ConsentRequestUi {

    override class var reuseId: String {
        return "analyticsCell"
    }

    override class var height: CGFloat {
        return 104
    }

    @IBOutlet weak var textLb: UILabel! {
        didSet {
            textLb.text = NSLocalizedString("Run health checks to help improve uploading.", comment: "")
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

    weak var delegate: AnalyticsCellDelegate?

    @IBAction func ok() {
        CleanInsights.shared.requestConsent(forCampaign: "upload_fails", self) { [weak self] consent in
            if consent?.granted ?? false {
                CleanInsights.shared.grant(feature: .lang)
            }

            self?.delegate?.analyticsReload()
        }
    }

    @IBAction func decline() {
        CleanInsights.shared.deny(campaign: "upload_fails")

        delegate?.analyticsReload()
    }


    // MARK: ConsentRequestUi

    func show(campaignId: String, campaign: Campaign, _ complete: @escaping CompleteCampaign) {
        delegate?.analyticsPresent(ConsentViewController.new(complete))
    }

    func show(feature: Feature, _ complete: @escaping CompleteFeature) {
        // Unused.
    }
}

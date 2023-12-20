//
//  GdriveWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.12.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST
import CleanInsightsSDK

class GdriveWizardViewController: BaseViewController, WizardDelegatable {

    var delegate: WizardDelegate?

    @IBOutlet weak var iconIv: UIImageView! {
        didSet {
            iconIv.image = .icGdrive
                .resizeFit(to: .icon)?
                .withRenderingMode(.alwaysTemplate)
        }
    }

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = GdriveSpace.defaultPrettyName
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = String(
                format: NSLocalizedString("Sign in with %@.",
                                          comment: "Placeholder is 'Google'"),
                "Google")
        }
    }

    @IBOutlet weak var backBt: UIButton! {
        didSet {
            backBt.setTitle(NSLocalizedString("Back", comment: ""))
        }
    }

    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle(NSLocalizedString("Authenticate", comment: ""))
        }
    }


    @IBAction func back() {
        delegate?.back()
    }

    @IBAction func next() {
        Task {
            let result: GIDSignInResult

            do {
                result = try await GIDSignIn.sharedInstance.signIn(withPresenting: self)
            }
            catch {
                AlertHelper.present(self, message: error.friendlyMessage)

                return
            }

            let space = GdriveSpace(userId: result.user.userID, accessToken: result.user.accessToken.tokenString)
            space.email = result.user.profile?.email

            SelectedSpace.space = space

            await Db.writeConn?.asyncReadWrite() { tx in
                SelectedSpace.store(tx)

                tx.setObject(space)
            }

            CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: "Google Drive")

            let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
            vc.spaceName = space.prettyName

            delegate?.next(vc, pos: 2)
        }
    }
}

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

    weak var delegate: WizardDelegate?

    @IBOutlet weak var iconIv: UIImageView! {
        didSet {
            iconIv.image = .icGdrive
                .resizeFit(to: .icon)?
                .withRenderingMode(.alwaysOriginal)
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
                GdriveSpace.googleName)
        }
    }

    @IBOutlet weak var disclaimerTv: UITextView! {
        didSet {
            // The document behind the link is english-only, this is its title.
            // Hence we do not translate it.
            let linkText = "Google API Services User Data Policy"

            // Beware: This line is forced upon us by Google. DO NOT CHANGE without prior consultation
            // of the Google terms!
            let line1 = String(
                format: NSLocalizedString(
                    "%1$@’s use and transfer of information received from %2$@ APIs to any other app adheres to %3$@, including the Limited Use requirements.",
                    comment: "HANDLE WITH CARE: This text is enforced by Google. If in doubt, how to translate correctly, leave it alone! Placeholder 1 is 'Save', placeholder 2 is 'Google', placeholder 3 is non-translatable 'Google API Services User Data Policy'"),
                Bundle.main.displayName,
                GdriveSpace.googleName,
                linkText)

            let line2 = String(
                format: NSLocalizedString(
                    "%1$@'s APIs allow you to send media to your %2$@ via %3$@. %3$@, however, cannot see or access anything on your %2$@, which you didn't create with %3$@ in the first place.",
                    comment: "Placeholder 1 is 'Google', placeholder 2 is 'Google Drive', placeholder 3 is 'Save'"),
                GdriveSpace.googleName,
                GdriveSpace.defaultPrettyName,
                Bundle.main.displayName)

            let text = NSMutableAttributedString(
                string: "\(line1)\n\n\(line2)",
                attributes: [.font: UIFont.montserrat(similarTo: disclaimerTv.font),
                             .foregroundColor: UIColor.label])

            text.link(part: linkText, href: "https://developers.google.com/terms/api-services-user-data-policy", into: disclaimerTv)

            disclaimerTv.attributedText = text
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
        let space = GdriveSpace()

        Self.authenticate(self, space: space) { [weak self] in
            CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: "Google Drive")

            let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
            vc.spaceName = space.prettyName

            self?.delegate?.next(vc, pos: 2)
        }
    }

    class func authenticate(_ vc: UIViewController, space: GdriveSpace, _ success: @escaping () -> Void) {
        Task {
            let result: GIDSignInResult

            do {
                result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: vc, hint: nil, additionalScopes: [kGTLRAuthScopeDriveFile])
            }
            catch {
                let error = error as NSError

                // Don't show an error dialog in this case:
                // -1: "access_denied" -: The user hit the "Cancel" button on the website.
                // -5: "The user canceled the sign-in flow.": The user hit the iOS "Cancel" button in the top left.
                if error.domain == "com.google.GIDSignIn" && (error.code == -1 || error.code == -5) {
                    return
                }

                AlertHelper.present(vc, message: error.friendlyMessage)

                return
            }

            guard result.user.grantedScopes?.contains(kGTLRAuthScopeDriveFile) ?? false
            else {
                AlertHelper.present(vc, message: String(
                    format: NSLocalizedString(
                        "%1$@ cannot work properly if you don't allow it to write to your %2$@. Please try the authorization again and make sure to grant *all* the access permissions listed.",
                        comment: "First placeholder is 'Save', second is 'Google Drive'."),
                    Bundle.main.displayName, GdriveSpace.defaultPrettyName) + "\n")

                return
            }

            GdriveConduit.user = result.user

            space.username = result.user.userID
            space.password = result.user.accessToken.tokenString
            space.email = result.user.profile?.email

            SelectedSpace.space = space

            await Db.writeConn?.asyncReadWrite() { tx in
                SelectedSpace.store(tx)

                tx.setObject(space)
            }

            success()
        }
    }
}

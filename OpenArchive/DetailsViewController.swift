//
//  DetailsViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 03.07.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit

class DetailsViewController: UIViewController {

    static let ccDomain = "creativecommons.org"
    static let ccUrl = "https://%@/licenses/%@/4.0/"

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var image: UIImageView!
    @IBOutlet var dateLb: UILabel!
    @IBOutlet var titleTf: UITextField!
    @IBOutlet var descriptionTf: UITextField!
    @IBOutlet var authorTf: UITextField!
    @IBOutlet var locationTf: UITextField!
    @IBOutlet var tagsTf: UITextField!
    @IBOutlet var licenseTf: UITextField!
    @IBOutlet var remixSw: UISwitch!
    @IBOutlet var shareAlikeSw: UISwitch!
    @IBOutlet var commercialSw: UISwitch!

    var imageObject: Image?

    lazy var writeConn = (UIApplication.shared.delegate as? AppDelegate)?.db?.newConnection()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Gesture Recognizer so the user can hide the keyboard again by tapping somewhere else
        // than the text field.
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.view.addGestureRecognizer(tapGestureRecognizer)

        image.image = imageObject?.image

        if let created = imageObject?.created {
            dateLb.text = Formatters.date.string(from: created)
        }

        titleTf.text = imageObject?.title
        descriptionTf.text = imageObject?.desc
        authorTf.text = imageObject?.author
        locationTf.text = imageObject?.location
        tagsTf.text = imageObject?.tags?.joined(separator: ", ")
        licenseTf.text = imageObject?.license

        if let license = imageObject?.license,
            license.localizedCaseInsensitiveContains(DetailsViewController.ccDomain) {

            remixSw.isOn = !license.localizedCaseInsensitiveContains("-nd")
            shareAlikeSw.isEnabled = remixSw.isOn
            shareAlikeSw.isOn = shareAlikeSw.isEnabled && license.localizedCaseInsensitiveContains("-sa")
            commercialSw.isOn = !license.localizedCaseInsensitiveContains("-nc")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(didShowKeyboard(_:)),
                                               name: .UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didHideKeyboard(_:)),
                                               name: .UIKeyboardDidHide, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardDidShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardDidHide, object: nil)

        super.viewWillDisappear(animated)
    }

    // MARK: Keyboard handling

    /**
     Callback for NotificationCenter .UIKeyboardDidShow observer.

     Adjusts the bottom inset of the scrollView, so the user can always scroll the full scene.

     - parameter notification: Provided by NotificationCenter.
     */
    @objc func didShowKeyboard(_ notification: Notification) {
        if let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {

            let bottom = keyboardFrame.cgRectValue.height
            scrollView?.contentInset.bottom = bottom
            scrollView?.scrollIndicatorInsets.bottom = bottom
        }
    }

    /**
     Callback for NotificationCenter .UIKeyboardDidHide observer.

     Adjusts the bottom inset of the scrollView, so the user can always scroll the full scene.

     - parameter notification: Provided by NotificationCenter.
     */
    @objc func didHideKeyboard(_ notification: Notification) {
        scrollView?.contentInset.bottom = 0
        scrollView?.scrollIndicatorInsets.bottom = 0
    }

    /**
     Dismisses the keyboard by ending editing on the main view.

     - parameter sender: The sending UITapGestureRecognizer.
     */
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    // MARK: Actions

    @IBAction func contentChanged(_ sender: UITextField) {
        if let i = imageObject {
            switch sender {
            case titleTf:
                i.title = titleTf.text
            case descriptionTf:
                i.desc = descriptionTf.text
            case authorTf:
                i.author = authorTf.text
            case locationTf:
                i.location = locationTf.text
            case tagsTf:
                let t = tagsTf.text?.split(separator: ",")
                var tags = [String]()

                t?.forEach() { tag in
                    tags.append(tag.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                i.tags = tags

            case licenseTf:
                i.license = licenseTf.text
            default:
                assertionFailure("This should have never happened - switch should be exhaustive.")
            }

            writeConn?.asyncReadWrite() { transaction in
                transaction.setObject(i, forKey: i.getKey(), inCollection: Asset.COLLECTION)
            }
        }
    }

    @IBAction func ccLicenseChanged(_ sender: UISwitch) {
        var license = "by"

        if remixSw.isOn {
            shareAlikeSw.isEnabled = true

            if !commercialSw.isOn {
                license += "-nc"
            }

            if shareAlikeSw.isOn {
                license += "-sa"
            }
        } else {
            shareAlikeSw.isEnabled = false
            shareAlikeSw.setOn(false, animated: true)

            if !commercialSw.isOn {
                license += "-nc"
            }

            license += "-nd"
        }

        licenseTf.text = String(format: DetailsViewController.ccUrl, DetailsViewController.ccDomain,
                                license)

        contentChanged(licenseTf)
    }

}

//
//  BatchEditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import AlignedCollectionViewFlowLayout

class BatchEditViewController: BaseViewController, InfoBoxDelegate {

    var assets: [Asset]?

    @IBOutlet weak var container: UIView!
    @IBOutlet weak var containerWidth: NSLayoutConstraint!

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosHeight: NSLayoutConstraint!
    @IBOutlet weak var infosBottom: NSLayoutConstraint!

    private var dh: DarkroomHelper?

    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = NSLocalizedString("Batch Edit", comment: "")
        title.subtitle.text = String.localizedStringWithFormat(NSLocalizedString("%u Item(s) Selected", comment: "#bc-ignore!"), assets?.count ?? 0)
        navigationItem.titleView = title

        var lastIv: UIImageView?

        for asset in assets ?? [] {
            let iv = UIImageView(image: asset.getThumbnail())
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(iv)

            iv.topAnchor.constraint(equalTo: container.topAnchor, constant: 8).isActive = true
            iv.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 8).isActive = true
            iv.addConstraint(NSLayoutConstraint(
                item: iv, attribute: .height, relatedBy: .equal, toItem: iv,
                attribute: .width, multiplier: iv.intrinsicContentSize.height / iv.intrinsicContentSize.width,
                constant: 0))

            if let lastIv = lastIv {
                iv.leadingAnchor.constraint(equalTo: lastIv.trailingAnchor, constant: 8).isActive = true
            }
            else {
                iv.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8).isActive = true
            }

            lastIv = iv
        }

        lastIv?.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 8).isActive = true

        dh = DarkroomHelper(self, infos)

        // These constraints are solely there to stop Interface Builder complaining
        // about missing sizing. It's actually unneeded. The sizes will
        // be automatically defined by its content, which whe have injected above.
        containerWidth.isActive = false
        infosHeight.isActive = false

        dh?.setInfos(assets?.first, defaults: true, isEditable: true)

        hideKeyboardOnOutsideTap()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: BaseViewController

    override func keyboardWillShow(notification: Notification) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))

        if let kbSize = getKeyboardSize(notification) {
            infosBottom.constant = kbSize.height

            animateDuringKeyboardMovement(notification)
        }
    }

    override func keyboardWillBeHidden(notification: Notification) {
        navigationItem.rightBarButtonItem = nil

        infosBottom.constant = 0

        animateDuringKeyboardMovement(notification)
    }


    // MARK: InfoBoxDelegate

    /**
     Callback for `desc`, `location` and `notes`.

     Store changes.
     */
    func textChanged(_ infoBox: InfoBox, _ text: String) {
        guard let assets = assets,
              let update = dh?.assign((infoBox, text))
        else {
            return
        }

        Asset.update(assets: assets, update)
        { [weak self] assets in
            self?.assets = assets
        }
    }

    func tapped(_ infoBox: InfoBox) {
        guard let assets = assets else {
            return
        }

        // Take the first's status and set all of them to that.
        let flagged = !(assets.first?.flagged ?? false)

        let update = dh?.assign(dh?.getFirstResponder())

        Asset.update(assets: assets, { asset in
            asset.flagged = flagged

            update?(asset)
        }) { [weak self] in
            self?.assets = $0
        }

        dh?.setInfos(assets.first, defaults: true, isEditable: true)

        FlagInfoAlert.presentIfNeeded()
    }
}

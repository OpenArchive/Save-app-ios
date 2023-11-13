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

    @IBOutlet weak var image1: UIImageView!
    @IBOutlet weak var image2: UIImageView!
    @IBOutlet weak var image3: UIImageView!

    @IBOutlet weak var counterLb: UILabel!
    @IBOutlet weak var flagBt: UIButton! {
        didSet {
            flagBt.setTitle("")
            flagBt.setImage(.init(systemName: "flag.fill"), for: .selected)
        }
    }

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosBottom: NSLayoutConstraint?

    private var dh: DarkroomHelper?

    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = NSLocalizedString("Edit Media Info", comment: "")
        title.subtitle.text = String.localizedStringWithFormat(NSLocalizedString("%u Item(s) Selected", comment: "#bc-ignore!"), assets?.count ?? 0)
        navigationItem.titleView = title

        counterLb.text = Formatters.format(assets?.count ?? 0)
        flagBt.isSelected = assets?.reduce(true, { $0 && $1.flagged }) ?? false

        setImage(image1, assets?.first)
        setImage(image2, assets?.count ?? 0 > 1 ? assets?[1] : nil)
        setImage(image3, assets?.count ?? 0 > 2 ? assets?[2] : nil)

        // Use the new keyboard layout guide, if available, that's more reliable
        // than any calculation.
        if #available(iOS 15.0, *) {
            infosBottom?.isActive = false
            infos.bottomAnchor.constraint(equalTo: infos.keyboardLayoutGuide.topAnchor).isActive = true
        }

        dh = DarkroomHelper(self, infos)

        dh?.setInfos(assets?.first, defaults: true)

        hideKeyboardOnOutsideTap()
    }

    private func setImage(_ iv: UIImageView, _ asset: Asset?) {
        if let image = asset?.getThumbnail() {
            iv.image = image
            iv.show2()
        }
        else {
            iv.hide()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: BaseViewController

    override func keyboardWillShow(notification: Notification) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))

        if let infosBottom = infosBottom,
           let kbSize = getKeyboardSize(notification)
        {
            infosBottom.constant = view.bounds.maxY - kbSize.minY
        }

        animateDuringKeyboardMovement(notification)
    }

    override func keyboardWillBeHidden(notification: Notification) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismiss(_:)))

        infosBottom?.constant = 0

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
        toggleFlagged()
    }

    @IBAction func toggleFlagged() {
        guard let assets = assets else {
            return
        }

        let flagged = !flagBt.isSelected

        let update = dh?.assign(dh?.getFirstResponder())

        Asset.update(assets: assets, { asset in
            asset.flagged = flagged

            update?(asset)
        }) { [weak self] in
            self?.assets = $0
        }

        flagBt.isSelected = flagged

        dh?.setInfos(assets.first, defaults: true)

        FlagInfoAlert.presentIfNeeded()
    }
}

//
//  BatchEditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BatchEditViewController: BaseViewController, InfoBoxDelegate {
    
    var assets: [Asset]?
    
    @IBOutlet weak var image1: UIImageView!
    @IBOutlet weak var image2: UIImageView!
    @IBOutlet weak var image3: UIImageView!
    
    @IBOutlet weak var counterLb: UILabel!{
        didSet{
            counterLb.cornerRadius = 10
            counterLb.clipsToBounds = true
        }
    }
    @IBOutlet weak var flagIv: Flag!
    
    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosBottom: NSLayoutConstraint?
    private var keyboardConstraint: NSLayoutConstraint?
    private var dh: DarkroomHelper?
    private var originalRightBarButtonItem: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title =   NSLocalizedString("Bulk Edit Media Info", comment: "")

        navigationItem.title = title

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "DONE",
            style: .done,
            target: self,
            action: #selector(dismiss(_:))
        )
        originalRightBarButtonItem = navigationItem.rightBarButtonItem

        counterLb.text = Formatters.format(assets?.count ?? 0)
        
        flagIv.isSelected = assets?.reduce(true, { $0 && $1.flagged }) ?? false
        setImage(image1, assets?.first)
        setImage(image2, assets?.count ?? 0 > 1 ? assets?[1] : nil)
        setImage(image3, assets?.count ?? 0 > 2 ? assets?[2] : nil)
        
        
        // Store the starting button
        originalRightBarButtonItem = navigationItem.rightBarButtonItem
        
        
        if #available(iOS 15.0, *) {
            infosBottom?.isActive = false
            keyboardConstraint = infos.bottomAnchor.constraint(
                equalTo: view.keyboardLayoutGuide.topAnchor,
                constant: -20
            )
            keyboardConstraint?.priority = .defaultHigh
            keyboardConstraint?.isActive = true
        } else {
            infosBottom?.constant = GeneralConstants.constraint_20
        }
        
        dh = DarkroomHelper(self, infos)
        dh?.setInfos(assets?.first, defaults: true, infos.frame.height * 0.6)
        hideKeyboardOnOutsideTap()
    }
    
    
    private func setImage(_ iv: UIImageView, _ asset: Asset?) {
        if let asset = asset {
            if asset.hasThumbnail(), let image = asset.getThumbnail() {
                iv.image = image
                iv.show2()
            }
            else {
                let placeholderImage = UIImage(named: asset.getFileType().placeholder)?
                    .withRenderingMode(.alwaysTemplate)
                
                iv.image = placeholderImage
                iv.backgroundColor = .placeholderBackground
                iv.tintColor = .placeholderFile
                iv.contentMode = .scaleAspectFit
                iv.clipsToBounds = true
                iv.show2()
            }
        } else {
            iv.hide()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trackScreenViewSafely("BatchEdit")
    }
    
    
    // MARK: - Keyboard
    
    override func keyboardWillShow(notification: Notification) {
        let doneButton = UIBarButtonItem(
            title: "DONE",
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        navigationItem.rightBarButtonItem = doneButton

        if #available(iOS 15.0, *) {
            keyboardConstraint?.constant = GeneralConstants.zeroConstraint
            view.layoutIfNeeded()
        } else {
            infosBottom?.constant = GeneralConstants.zeroConstraint
            view.layoutIfNeeded()
        }
    }
    
    
    override func keyboardWillBeHidden(notification: Notification) {
        navigationItem.rightBarButtonItem = originalRightBarButtonItem

        animateDuringKeyboardMovement(notification)
        
        if #available(iOS 15.0, *) {
            keyboardConstraint?.constant = GeneralConstants.constraint_minus_20
            view.layoutIfNeeded()
        } else {
            infosBottom?.constant = GeneralConstants.constraint_20
            view.layoutIfNeeded()
        }
    }
    
    
    // MARK: - InfoBoxDelegate
    
    func textChanged(_ infoBox: InfoBox, _ text: String) {
        guard let assets = assets,
              let update = dh?.assign((infoBox, text))
        else {
            return
        }
        
        Asset.update(assets: assets, update) { [weak self] assets in
            self?.assets = assets
        }
    }
    
    func tapped(_ infoBox: InfoBox) {
        toggleFlagged()
    }
    
    
    @IBAction func toggleFlagged() {
        guard let assets = assets else { return }
        
        let flagged = !flagIv.isSelected
        let update = dh?.assign(dh?.getFirstResponder())
        
        Asset.update(assets: assets, { asset in
            asset.flagged = flagged
            update?(asset)
        }) { [weak self] in
            self?.assets = $0
        }

        flagIv.isSelected = flagged
        FlagInfoAlert.presentIfNeeded()
    }
}

extension Notification {
    func keyboardHeight() -> CGFloat? {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue.height
    }
}

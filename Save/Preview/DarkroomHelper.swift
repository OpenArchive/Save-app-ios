//
//  DarkroomHelper.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 08.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class DarkroomHelper {

    private static let descPlaceholder = NSLocalizedString("Add People", comment: "")
    private static let locPlaceholder = NSLocalizedString("Add Location", comment: "")
    private static let notesPlaceholder = NSLocalizedString("Add Notes", comment: "")
    private static let flagPlaceholder = NSLocalizedString("Tap to flag as significant content", comment: "")


    let delegate: InfoBoxDelegate

    let publicUrl: InfoBox?
    let desc: InfoBox?
    let location: InfoBox?
    let notes: InfoBox?
    let flag: InfoBox?


    init(_ delegate: InfoBoxDelegate, _ superview: UIView) {
        self.delegate = delegate

        publicUrl = InfoBox.instantiate("ic_cloud", superview)
        publicUrl?.textView.isEditable = false
        publicUrl?.textView.isSelectable = false

        desc = InfoBox.instantiate("ic_tag", superview)
        desc?.delegate = delegate

        location = InfoBox.instantiate("ic_location", superview)
        location?.delegate = delegate

        notes = InfoBox.instantiate("ic_edit", superview)
        notes?.delegate = delegate

        flag = InfoBox.instantiate("ic_flag", superview)

        flag?.icon.tintColor = .warning
        flag?.textView.isEditable = false
        flag?.textView.isSelectable = false

        var tap = UITapGestureRecognizer(target: self, action: #selector(flagged))
        tap.cancelsTouchesInView = true
        flag?.addGestureRecognizer(tap)

        tap = UITapGestureRecognizer(target: self, action: #selector(followLink))
        tap.cancelsTouchesInView = true
        publicUrl?.addGestureRecognizer(tap)

        publicUrl?.addConstraints(superview, bottom: desc)
        desc?.addConstraints(superview, top: publicUrl, bottom: location)
        location?.addConstraints(superview, top: desc, bottom: notes)
        notes?.addConstraints(superview, top: location, bottom: flag)
        flag?.addConstraints(superview, top: notes)
    }


    // MARK: Public Methods

    func setInfos(_ asset: Asset?, defaults: Bool = false, isEditable: Bool = true) {
        publicUrl?.set(asset?.space is IaSpace ? asset?.publicUrl?.absoluteString : nil)

        desc?.set(asset?.desc, with: defaults ? DarkroomHelper.descPlaceholder : nil)
        desc?.textView.isEditable = isEditable

        location?.set(asset?.location, with: defaults ? DarkroomHelper.locPlaceholder : nil)
        location?.textView.isEditable = isEditable

        notes?.set(asset?.notes, with: defaults ? DarkroomHelper.notesPlaceholder : nil)
        notes?.textView.isEditable = isEditable

        flag?.set(asset?.flagged ?? false ? NSLocalizedString("Significant Content", comment: "") : nil,
                  with: defaults ? DarkroomHelper.flagPlaceholder : nil)
    }

    func getFirstResponder() -> (infoBox: InfoBox?, value: String?) {
        if desc?.textView.isFirstResponder ?? false {
            return (desc, desc?.textView.text)
        }

        if location?.textView.isFirstResponder ?? false {
            return (location, location?.textView.text)
        }

        if notes?.textView.isFirstResponder ?? false {
            return (notes, notes?.textView.text)
        }

        return (nil, nil)
    }

    func assign(_ info: (infoBox: InfoBox?, value: String?)?) -> ((_ asset: AssetProxy) -> Void)? {
        switch  info?.infoBox {
        case nil:
            return nil

        case desc:
            return { asset in
                asset.desc = info?.value
            }

        case location:
            return { asset in
                asset.location = info?.value
            }

        case notes:
            return { asset in
                asset.notes = info?.value
            }

        default:
            return nil
        }
    }


    // MARK: Private Methods

    @objc private func flagged() {
        if let flag = flag {
            delegate.tapped(flag)
        }
    }

    @objc private func followLink() {
        if let urlString = publicUrl?.textView.text,
            let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

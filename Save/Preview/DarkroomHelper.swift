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
    private static let locPlaceholder = NSLocalizedString("Add a location (optional)", comment: "")
    private static let notesPlaceholder = NSLocalizedString("Add notes (optional)", comment: "")
    private static let flagPlaceholder = NSLocalizedString("Tap to flag as significant content", comment: "")


    let delegate: InfoBoxDelegate

//    let desc: InfoBox?
    let location: InfoBox?
    let notes: InfoBox?
//    let flag: InfoBox?


    init(_ delegate: InfoBoxDelegate, _ superview: UIView) {
        self.delegate = delegate

//        desc = InfoBox.instantiate("ic_tag", superview)
//        desc?.delegate = delegate

        location = InfoBox.instantiate("ic_location", superview)
        location?.delegate = delegate

        notes = InfoBox.instantiate("ic_edit", superview)
        notes?.delegate = delegate

//        flag = InfoBox.instantiate("ic_flag", superview)
//
//        flag?.icon.tintColor = .warning
//        flag?.textView.isEditable = false
//        flag?.textView.isSelectable = false
//
//        var tap = UITapGestureRecognizer(target: self, action: #selector(flagged))
//        tap.cancelsTouchesInView = true
//        flag?.addGestureRecognizer(tap)
//
//        desc?.addConstraints(superview, bottom: location)
        location?.addConstraints(superview, bottom: notes)
        notes?.addConstraints(superview, top: location)
//        flag?.addConstraints(superview, top: notes)
    }


    // MARK: Public Methods

    func setInfos(_ asset: Asset?, defaults: Bool = false, isEditable: Bool = true) {
//        desc?.set(asset?.desc, with: defaults ? DarkroomHelper.descPlaceholder : nil)
//        desc?.textView.isEditable = isEditable

        location?.set(asset?.location, with: defaults ? DarkroomHelper.locPlaceholder : nil)
        location?.textView.isEditable = isEditable

        notes?.set(asset?.notes, with: defaults ? DarkroomHelper.notesPlaceholder : nil)
        notes?.textView.isEditable = isEditable

//        flag?.set(asset?.flagged ?? false ? NSLocalizedString("Significant Content", comment: "") : nil,
//                  with: defaults ? DarkroomHelper.flagPlaceholder : nil)
    }

    func getFirstResponder() -> (infoBox: InfoBox?, value: String?) {
//        if desc?.textView.isFirstResponder ?? false {
//            return (desc, desc?.textView.text)
//        }

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

//        case desc:
//            return { asset in
//                asset.desc = info?.value
//            }

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

//    @objc private func flagged() {
//        if let flag = flag {
//            delegate.tapped(flag)
//        }
//    }
}

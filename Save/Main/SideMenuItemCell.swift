//
//  SideMenuItemCell.swift
//  Save
//
//  Created by Benjamin Erhart on 28.09.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SideMenuItemCell: UITableViewCell {

    class var nib: UINib {
        UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        String(describing: self)
    }


    @IBOutlet weak var iconLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var nameLb: UILabel!


    func apply(_ space: Space?, select: Bool) {
        iconLeadingConstraint.constant = 12

        icon.image = space?.favIcon ?? SelectedSpace.defaultFavIcon
        icon.tintColor = UIColor.label
        nameLb.text = space?.prettyName ?? Bundle.main.displayName
        nameLb.font =  .montserrat(forTextStyle: .caption2)
        nameLb.textColor = .label
        contentView.backgroundColor = select ? .accent :  .pillBackground
    }

    func apply(_ project: Project?, select: Bool) {
        iconLeadingConstraint.constant = 12

        icon.image = UIImage(systemName: select ? "folder.fill" : "folder")?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = select ? .accent : .label

        nameLb.text = project?.name
        nameLb.font = .montserrat(forTextStyle: .callout ,with: .traitUIOptimized)
        nameLb.textColor = select ? UIColor.label : .gray70

        contentView.backgroundColor = .clear
    }

    func applyAdd() {
        iconLeadingConstraint.constant = 12

        icon.image = UIImage(systemName: "plus")?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = .accent

        nameLb.text = NSLocalizedString("Add new server", comment: "")
        nameLb.font =  .montserrat(forTextStyle: .caption2)
        nameLb.textColor = .accent

        contentView.backgroundColor = .pillBackground
    }
}

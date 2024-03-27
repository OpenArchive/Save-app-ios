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
        iconLeadingConstraint.constant = 8

        icon.image = space?.favIcon ?? SelectedSpace.defaultFavIcon
        icon.tintColor = select ? .accent : .label

        nameLb.text = space?.prettyName ?? Bundle.main.displayName
        nameLb.textColor = select ? .accent : .label
    }

    func apply(_ project: Project?, select: Bool) {
        iconLeadingConstraint.constant = 24

        icon.image = UIImage(systemName: select ? "folder.fill" : "folder")?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = select ? .accent : .label

        nameLb.text = project?.name
        nameLb.textColor = select ? .accent : .label

        contentView.backgroundColor = .clear
    }

    func applyAdd() {
        iconLeadingConstraint.constant = 8

        icon.image = UIImage(systemName: "plus")?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = .label

        nameLb.text = NSLocalizedString("Add Server", comment: "")
        nameLb.textColor = .label

        contentView.backgroundColor = .secondarySystemBackground
    }
}

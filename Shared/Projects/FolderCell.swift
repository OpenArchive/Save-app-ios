//
//  FolderCell.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class FolderCell: BaseCell {

    @IBOutlet weak var folderIcon: TintedImageView!
    @IBOutlet weak var nameLb: UILabel!

    private var customBackgroundView: UIView!
    override func awakeFromNib() {
        super.awakeFromNib()

        // Define and add the custom background view
        let padding: CGFloat = 4
        customBackgroundView = UIView(frame: CGRect(
            x: padding,
            y: padding,
            width: bounds.width - 2 * padding,
            height: bounds.height - 2 * padding
        ))

        customBackgroundView.backgroundColor = .clear
        customBackgroundView.layer.cornerRadius = 8
        customBackgroundView.layer.masksToBounds = true
        customBackgroundView.layer.borderWidth = 0
        customBackgroundView.layer.borderColor = UIColor.clear.cgColor

        addSubview(customBackgroundView)
        sendSubviewToBack(customBackgroundView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Dynamically update the customBackgroundView frame to adjust to cell size
        let padding: CGFloat = 4
        customBackgroundView.frame = CGRect(
            x: padding,
            y: padding,
            width: bounds.width - 2 * padding,
            height: bounds.height - 2 * padding
        )
    }

    @discardableResult
    func set(folder: BrowseViewController.Folder) -> FolderCell {
        nameLb.text = folder.name
        return self
    }
  
    func updateBorder(isSelected: Bool) {
           if isSelected {
               customBackgroundView.layer.borderColor = UIColor.accent.cgColor
               customBackgroundView.layer.borderWidth = 2
               customBackgroundView.backgroundColor = .accent
           } else {
               customBackgroundView.layer.borderColor = UIColor.clear.cgColor
               customBackgroundView.layer.borderWidth = 0
               customBackgroundView.backgroundColor = UIColor.clear
           }
       }
       
}

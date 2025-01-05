//
//  SeverCellNew.swift
//  Save
//
//  Created by navoda on 2024-12-27.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit

class ServerCellNew: UITableViewCell {
    
    // Container for the content excluding the bottom padding
    private let borderedContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let serverIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "folder")
        imageView.tintColor = .systemTeal
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let serverNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let editButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "pencil"), for: .normal)
        button.tintColor = .systemGray
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let bottomPaddingView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Closure for handling edit button tap
    var editButtonAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.backgroundColor = .clear
        selectionStyle = .none 
        // Add subviews
        contentView.addSubview(borderedContainer)
        borderedContainer.addSubview(serverIcon)
        borderedContainer.addSubview(serverNameLabel)
        borderedContainer.addSubview(editButton)
        contentView.addSubview(bottomPaddingView)
        
        // Constraints for borderedContainer
        NSLayoutConstraint.activate([
            borderedContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            borderedContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            borderedContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            borderedContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8) // Exclude bottom padding
        ])
        
        // Constraints for folderIcon
        NSLayoutConstraint.activate([
            serverIcon.leadingAnchor.constraint(equalTo: borderedContainer.leadingAnchor, constant: 16),
            serverIcon.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            serverIcon.widthAnchor.constraint(equalToConstant: 24),
            serverIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Constraints for folderNameLabel
        NSLayoutConstraint.activate([
            serverNameLabel.leadingAnchor.constraint(equalTo: serverIcon.trailingAnchor, constant: 16),
            serverNameLabel.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            serverNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -16)
        ])
        
        // Constraints for editButton
        NSLayoutConstraint.activate([
            editButton.trailingAnchor.constraint(equalTo: borderedContainer.trailingAnchor, constant: -16), // Right padding
            editButton.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 24),
            editButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Constraints for bottomPaddingView
        NSLayoutConstraint.activate([
            bottomPaddingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomPaddingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomPaddingView.topAnchor.constraint(equalTo: borderedContainer.bottomAnchor),
            bottomPaddingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomPaddingView.heightAnchor.constraint(equalToConstant: 10) // Bottom padding
        ])
        
        // Add action to editButton
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Configure the cell with folder data
    func configure(with space:Space, isSelected: Bool) {
        serverNameLabel.text = space.name
        serverIcon.image = space.favIcon ?? SelectedSpace.defaultFavIcon
        serverIcon.tintColor = isSelected ? .accent : .label
        if isSelected {
            // Archived folder appearance
            borderedContainer.backgroundColor = UIColor.systemGray6
            borderedContainer.layer.borderWidth = 1
            borderedContainer.layer.borderColor = UIColor.systemTeal.cgColor
        } else {
           
            if traitCollection.userInterfaceStyle == .dark {
                borderedContainer.backgroundColor = UIColor.black
            } else {
                borderedContainer.backgroundColor = UIColor.white
            }
            borderedContainer.layer.borderWidth = 0
        }
    }
    
    @objc private func editButtonTapped() {
        editButtonAction?()
    }
}

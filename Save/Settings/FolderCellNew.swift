import UIKit

class FolderCellNew: UITableViewCell {
    
    // Container for the content excluding the bottom padding
    private let borderedContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let folderIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "folder")
        imageView.tintColor = .systemTeal
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let folderNameLabel: UILabel = {
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
        selectionStyle = .none 
        contentView.backgroundColor = .clear
        
        // Add subviews
        contentView.addSubview(borderedContainer)
        borderedContainer.addSubview(folderIcon)
        borderedContainer.addSubview(folderNameLabel)
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
            folderIcon.leadingAnchor.constraint(equalTo: borderedContainer.leadingAnchor, constant: 16), // Left padding
            folderIcon.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 24),
            folderIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Constraints for folderNameLabel
        NSLayoutConstraint.activate([
            folderNameLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 16), // Space between icon and label
            folderNameLabel.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            folderNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -16) // Space before edit button
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
    func configure(with folderName: String, isSelected: Bool) {
        folderNameLabel.text = folderName
        folderIcon.image = UIImage(systemName: isSelected ? "folder.fill" : "folder")?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = isSelected ? .accent : .label
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

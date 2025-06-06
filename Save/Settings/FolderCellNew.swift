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
        imageView.image = UIImage(named: "folder_icon")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let folderNameLabel: UILabel = {
        let label = UILabel()
        label.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
  
    
    private let bottomPaddingView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.backgroundColor = .clear
        
        contentView.addSubview(borderedContainer)
        borderedContainer.addSubview(folderIcon)
        borderedContainer.addSubview(folderNameLabel)
      
        contentView.addSubview(bottomPaddingView)
   
        NSLayoutConstraint.activate([
            borderedContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            borderedContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            borderedContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            borderedContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8) // Exclude bottom padding
        ])
      
        NSLayoutConstraint.activate([
            folderIcon.leadingAnchor.constraint(equalTo: borderedContainer.leadingAnchor, constant: 16), // Left padding
            folderIcon.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 44),
            folderIcon.heightAnchor.constraint(equalToConstant: 44)
        ])
     
        NSLayoutConstraint.activate([
            folderNameLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 16), // Space between icon and label
            folderNameLabel.centerYAnchor.constraint(equalTo: borderedContainer.centerYAnchor),
            folderNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: borderedContainer.trailingAnchor, constant: -16) // Space before edit button
        ])
        
        NSLayoutConstraint.activate([
            bottomPaddingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomPaddingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomPaddingView.topAnchor.constraint(equalTo: borderedContainer.bottomAnchor),
            bottomPaddingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomPaddingView.heightAnchor.constraint(equalToConstant: 10)
        ])
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with folderName: String) {
        folderNameLabel.text = folderName
        folderIcon.image = UIImage(systemName: isSelected ? "folder.fill" : "folder")?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = isSelected ? .accent : .label

    }
    
   
}

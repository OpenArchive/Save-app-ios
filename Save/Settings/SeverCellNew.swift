import UIKit

class ServerCellNew: UITableViewCell {
    
    private let serverIcon = UIImageView()
    private let serverNameLabel = UILabel()
    private let serverSubtitleLabel = UILabel()
    private let bottomPaddingView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        selectionStyle = .none
        
        [serverIcon, serverNameLabel, serverSubtitleLabel, bottomPaddingView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        serverIcon.image = UIImage(systemName: "server.rack")
        serverIcon.tintColor = .label
        serverIcon.contentMode = .scaleAspectFit
        
        serverNameLabel.font = UIFont.montserrat(forTextStyle: .headline, with: .traitUIOptimized)
        serverNameLabel.textColor = .label
        
        serverSubtitleLabel.font = UIFont.montserrat(forTextStyle: .subheadline)
        serverSubtitleLabel.textColor = .subtitleText
        
        bottomPaddingView.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            serverIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            serverIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            serverIcon.widthAnchor.constraint(equalToConstant: 40),
            serverIcon.heightAnchor.constraint(equalToConstant: 40),
            
            serverNameLabel.leadingAnchor.constraint(equalTo: serverIcon.trailingAnchor, constant: 16),
            serverNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            serverNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            serverSubtitleLabel.leadingAnchor.constraint(equalTo: serverNameLabel.leadingAnchor),
            serverSubtitleLabel.topAnchor.constraint(equalTo: serverNameLabel.bottomAnchor, constant: 2),
            serverSubtitleLabel.trailingAnchor.constraint(equalTo: serverNameLabel.trailingAnchor),
            
            bottomPaddingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomPaddingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomPaddingView.topAnchor.constraint(equalTo: serverSubtitleLabel.bottomAnchor, constant: 4),
            bottomPaddingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomPaddingView.heightAnchor.constraint(equalToConstant: 15) // Bottom padding
        ])
    }
    
    func configure(with space: Space) {
        serverNameLabel.text = space.name
        serverIcon.image = space.favIcon ?? SelectedSpace.defaultFavIcon
        serverIcon.tintColor = isSelected ? .accent : .label
        serverSubtitleLabel.text = getServerType(for: space)
    }
    
    private func getServerType(for space: Space) -> String {
        if space is IaSpace {
            return NSLocalizedString("Internet Archive", comment: "")
        } else if space is WebDavSpace {
            return NSLocalizedString("Private Server", comment: "")
        } else {
            return NSLocalizedString("Unknown Server", comment: "")
        }
    }
}

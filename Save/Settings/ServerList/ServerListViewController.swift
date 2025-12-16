import UIKit
import YapDatabase
import SwiftUI

class ServerListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    private var spacesConn = Db.newLongLivedReadConn()
    private var spacesMappings = YapDatabaseViewMappings(
        groups: SpacesView.groups, view: SpacesView.name)
    var selectSpace = false
    
    private let noDataLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("No servers added yet.", comment: "")
        label.textAlignment = .center
        label.font = .montserrat(forTextStyle: .headline, with:.traitUIOptimized)
        label.textColor = .gray70
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addServerButton: UIButton = {
         let button = UIButton(type: .system)
         button.setTitle(NSLocalizedString("Add Server", comment: ""), for: .normal)
         button.backgroundColor = .accent
        button.setTitleColor(.black, for: .normal)
         button.titleLabel?.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
         button.layer.cornerRadius = 10
         button.translatesAutoresizingMaskIntoConstraints = false
         
         // Add plus icon
         let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
         let plusImage = UIImage(systemName: "plus", withConfiguration: config)
         button.setImage(plusImage, for: .normal)
        button.tintColor = .black
         button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
         button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
         
         return button
     }()

    override func viewWillDisappear(_ animated: Bool) {
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trackScreenViewSafely("ServerLList")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = NSLocalizedString("Media Servers", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ServerCell.self, forCellReuseIdentifier: "ServerCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        view.addSubview(noDataLabel)
        view.addSubview(addServerButton)
        
        // Add target for button
        addServerButton.addTarget(self, action: #selector(addServerTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            noDataLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noDataLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            noDataLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            noDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: addServerButton.topAnchor, constant: -16)
        ])
        
        NSLayoutConstraint.activate([
            addServerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 75),
            addServerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -75),
            addServerButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addServerButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        Db.add(observer: self, #selector(yapDatabaseModified))
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool) {
        spacesConn?.update(mappings: spacesMappings)
        noDataLabel.isHidden = (spacesMappings.numberOfItems(inSection: 0) > 0)
        tableView.reloadData()
    }
    
    @objc private func addServerTapped() {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let spaceSelectionVC = storyboard.instantiateViewController(withIdentifier: "SpaceTypeViewController") as? SpaceTypeViewController {
               navigationController?.pushViewController(spaceSelectionVC, animated: true)
           }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(spacesMappings.numberOfItems(inSection: UInt(section)))
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ServerCell", for: indexPath) as? ServerCell else {
            return UITableViewCell()
        }
        if let space = getSpace(at: indexPath) {
            cell.configure(with: space)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        editServer(at: indexPath)
    }
    
    func editServer(at indexPath: IndexPath) {
        if let space = getSpace(at: indexPath) {
            switch space {
            case let space as IaSpace:
                self.navigationController?.pushViewController(InternetArchiveDetailsController(space: space), animated: true)
                
            case is WebDavSpace:
                let vc = PrivateServerSettingViewController()
                vc.space = space
                navigationController?.pushViewController(vc, animated: true)
            default:
                print("no navigation")
            }
        }
    }
    
    @objc
    private func yapDatabaseModified(_ notification: Notification) {
        noDataLabel.isHidden = (spacesMappings.numberOfItems(inSection: 0) > 0)
        if spacesConn?.hasChanges(spacesMappings) ?? false {
            tableView.reloadData()
        }
    }
    
    private func getSpace(at indexPath: IndexPath) -> Space? {
        spacesConn?.object(at: indexPath, in: spacesMappings)
    }
}


import UIKit


import UIKit
import YapDatabase
import SwiftUICore

class ServerListNewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private static let webDavSettingsSegue = "webDavSettingsSegue"
    private static let iaSettingsSegue = "iaSettingsSegue"

    let tableView = UITableView()
    let addButton = UIButton()
    var delegate: SideMenuDelegate?
    private var spacesConn = Db.newLongLivedReadConn()
    var projectsConn: YapDatabaseConnection?
    var projectsMappings: YapDatabaseViewMappings?
    var fromSetting = false
    private var spacesMappings = YapDatabaseViewMappings(
        groups: SpacesView.groups, view: SpacesView.name)
    var selectSpace = false

    init(delegate: SideMenuDelegate? = nil, projectsConn: YapDatabaseConnection? = nil, projectsMappings: YapDatabaseViewMappings? = nil) {
           self.delegate = delegate
           self.projectsConn = projectsConn
           self.projectsMappings = projectsMappings
           super.init(nibName: nil, bundle: nil)
       }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        if(selectSpace){
            delegate?.selectSpace()
            selectSpace = false
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = "Servers"
        
        // Set up the TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ServerCellNew.self, forCellReuseIdentifier: "ServerCellNew")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.setTitle(NSLocalizedString("Add Server", comment: ""), for: .normal) // Add space before title for padding
        addButton.tintColor = .white // Tint color for the image
        addButton.setTitleColor(.white, for: .normal) // Title color
        if #available(iOS 15.0, *) {
            addButton.backgroundColor = UIColor.systemMint
        } else {
            addButton.backgroundColor = UIColor.systemTeal
        }
        addButton.layer.cornerRadius = 28
        addButton.translatesAutoresizingMaskIntoConstraints = false

        addButton.addTarget(self, action: #selector(addServer), for: .touchUpInside)
        addButton.contentHorizontalAlignment = .center
        addButton.contentVerticalAlignment = .center
        addButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 0) // Adjust spacing between image and text
        addButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        view.addSubview(addButton)
        
        // Constraints for TableView
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        
        // Constraints for Add Button
        NSLayoutConstraint.activate([
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.heightAnchor.constraint(equalToConstant: 56),
            addButton.widthAnchor.constraint(equalToConstant: 200)
        ])
        Db.add(observer: self, #selector(yapDatabaseModified))
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
    
    }
    override func viewWillAppear(_ animated: Bool) {
        spacesConn?.update(mappings: spacesMappings)
        tableView.reloadData()
    }
    // TableView DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(spacesMappings.numberOfItems(inSection: UInt(section)))
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ServerCellNew", for: indexPath) as? ServerCellNew else {
            return UITableViewCell()
        }
        if  let space = getSpace(at: indexPath){
            
            cell.configure(with: space, isSelected: SelectedSpace.id == space.id)
        }
        cell.editButtonAction = { [weak self] in
            self?.editServer(at: indexPath)
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        SelectedSpace.space = getSpace(at: indexPath)
        SelectedSpace.store()
        selectSpace = true
        delegate?.selected(project: getProject(at: IndexPath(row: 0, section: 0)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            tableView.deselectRow(at: indexPath, animated: false)
            self.navigationController?.popViewController(animated: true)
        }
    }
    // Add Button Action
    @objc func addServer() {
        delegate?.addSpace()
       
    }
    
    // Edit Button Action
    func editServer(at indexPath: IndexPath) {
        
     
        if  let space = getSpace(at: indexPath){
            switch space{
            case let space as IaSpace:
                self.navigationController?.pushViewController(InternetArchiveDetailsController(space: space), animated: true)
                
            case is WebDavSpace:
                if(!fromSetting){
                    self.navigationController?.popViewController(animated: false)
                }
                delegate?.pushPrivateServerSetting(space: space,fromSetting: fromSetting)
                
            default:
                print("no navigation")
            }
            
        }
    }
    
    // TableView Delegate Method to add spacing between cells
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    @objc
    private func yapDatabaseModified(_ notification: Notification) {
        if spacesConn?.hasChanges(spacesMappings) ?? false {
            tableView.reloadData()
        }
      
    }
    
    private func getSpace(at indexPath: IndexPath) -> Space? {
        spacesConn?.object(at: indexPath, in: spacesMappings)
    }
                           private func getProject(at indexPath: IndexPath) -> Project? {
                               projectsConn?.object(at: indexPath, in: projectsMappings)
                           }

}

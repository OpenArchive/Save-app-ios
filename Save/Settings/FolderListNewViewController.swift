

import UIKit
import YapDatabase

class FolderListNewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    let addButton = UIButton()
    var delegate: SideMenuDelegate?

    var projectsConn: YapDatabaseConnection?

    var projectsMappings: YapDatabaseViewMappings?

    private var _selectedProject: Project?
    var selectedProject: Project? {
        get {
           
            if _selectedProject == nil {
                _selectedProject = getProject(at: IndexPath(row: 0, section: 0))
                if let project = _selectedProject {
                    delegate?.selected(project: project)
                }
            }
            return _selectedProject
        }
        set {
            _selectedProject = newValue
        }
    }


    init(delegate: SideMenuDelegate? = nil, projectsConn: YapDatabaseConnection? = nil, projectsMappings: YapDatabaseViewMappings? = nil, _selectedProject: Project? = nil) {
           self.delegate = delegate
           self.projectsConn = projectsConn
           self.projectsMappings = projectsMappings
           self._selectedProject = _selectedProject
           super.init(nibName: nil, bundle: nil) 
       }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = "Folders"
        
        // Set up the TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FolderCellNew.self, forCellReuseIdentifier: "FolderCellNew")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none // Remove separator lines
        view.addSubview(tableView)
        
        // Set up the Add Button
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = UIColor.systemTeal
        addButton.layer.cornerRadius = 28
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addFolder), for: .touchUpInside)
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
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56)
        ])
      

    
    }
    
    // TableView DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(projectsMappings?.numberOfItems(inSection: UInt(section)) ?? 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCellNew", for: indexPath) as? FolderCellNew else {
            return UITableViewCell()
        }
        let project = getProject(at: indexPath)

       
        cell.configure(with: project?.name ?? "", isSelected: selectedProject == project)
        cell.editButtonAction = { [weak self] in
            self?.editFolder(at: indexPath)
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedProject = getProject(at: indexPath)

        delegate?.selected(project: selectedProject)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            tableView.deselectRow(at: indexPath, animated: false)
            self.navigationController?.popViewController(animated: true)
        }
    }
    // Add Button Action
    @objc func addFolder() {
       
        self.navigationController?.pushViewController(AddFolderNewViewController(), animated: true)
    }
    
    // Edit Button Action
    func editFolder(at indexPath: IndexPath) {
        guard let project = getProject(at: indexPath) else { return  }
        self.navigationController?.pushViewController(EditFolderNewViewController(project), animated: true)
       
    }
    
    // TableView Delegate Method to add spacing between cells
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }


    
    private func getProject(at indexPath: IndexPath) -> Project? {
        projectsConn?.object(at: indexPath, in: projectsMappings)
    }

    private func contains(project: Project?) -> Bool {
        projectsConn?.indexPath(of: project, with: projectsMappings) != nil
    }
    func reload() {
        if !contains(project: selectedProject) {
            selectedProject = getProject(at: IndexPath(row: 0, section: 0))
        }

        tableView.reloadData()
    }
}

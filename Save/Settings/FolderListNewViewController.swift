import UIKit
import YapDatabase

class FolderListNewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    let archiveButton = UIButton()
    private let archived: Bool
    private lazy var projectsReadConn = Db.newLongLivedReadConn()
    var projectList: [Project] = []
    private lazy var projectsMappings = YapDatabaseViewMappings(
        groups: ProjectsView.groups, view: ProjectsView.name)

    private var hasArchived = false

    init(archived: Bool) {
        self.archived = archived
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        archived = aDecoder.decodeBool(forKey: "archived")
        super.init(coder: aDecoder)
    }

    override func encode(with coder: NSCoder) {
        coder.encode(archived, forKey: "archived")
        super.encode(with: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        title = NSLocalizedString("Folders", comment: "")
       
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FolderCellNew.self, forCellReuseIdentifier: "FolderCellNew")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        // Set up the archive button (only if there are archived folders)
        archiveButton.setTitle(NSLocalizedString("View Archived Folders", comment: ""), for: .normal)
        archiveButton.setTitleColor(.label, for: .normal)
        archiveButton.titleLabel?.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
        archiveButton.backgroundColor = UIColor.accent
        archiveButton.layer.cornerRadius = 10
        archiveButton.translatesAutoresizingMaskIntoConstraints = false
        archiveButton.addTarget(self, action: #selector(showArchivedFolders), for: .touchUpInside)
        archiveButton.contentHorizontalAlignment = .center
        archiveButton.contentVerticalAlignment = .center
        view.addSubview(archiveButton)
       
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        
        // Constraints for Archive Button
        NSLayoutConstraint.activate([
            archiveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            archiveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            archiveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            archiveButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        Db.add(observer: self, #selector(yapDatabaseModified))

        projectsReadConn?.update(mappings: projectsMappings)

        reload()
    }
   
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projectList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FolderCellNew", for: indexPath) as? FolderCellNew else {
            return UITableViewCell()
        }
        let project = projectList[indexPath.row]
        cell.configure(with: project.name ?? "")
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let project = projectList[indexPath.row]
        self.navigationController?.pushViewController(NewEditFolderViewController(project), animated: true)
    }
    
    // Show Archived Folders
    @objc func showArchivedFolders() {
        let archivedViewController = FolderListNewViewController(archived: true)
        self.navigationController?.pushViewController(archivedViewController, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    @objc private func yapDatabaseModified(_ notification: Notification) {
        if projectsReadConn?.hasChanges(projectsMappings) ?? false {
            reload()
        }
    }

    private func reload() {
        let projects: [Project] = projectsReadConn?.objects(in: 0, with: projectsMappings) ?? []
        
     
        hasArchived = !archived && projects.contains { !$0.active }

        projectList = projects.filter { archived != $0.active }
        
        archiveButton.isHidden = !hasArchived
        
        navigationItem.title = archived ? NSLocalizedString("Archived Folders", comment: "") :NSLocalizedString("Folders", comment: "")
        tableView.reloadData()
    }
}

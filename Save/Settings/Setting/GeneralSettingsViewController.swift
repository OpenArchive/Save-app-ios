
import UIKit
import SwiftUI
import YapDatabase
class GeneralSettingsViewController:UIViewController,ViewControllerNavigationDelegate {
    
    private lazy var ServerList: ServerListNewViewController = {
        let vc = ServerListNewViewController()
        return vc
    }()
    private lazy var FolderList: NewFolderListViewController = {
        let vc = NewFolderListViewController(archived: true)
        return vc
    }()
    
    let settingsViewModel = SettingsViewModel()
    
    func pushViewController(_ viewController: UIViewController) {
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    func pushServerList() {
        
        self.navigationController?.pushViewController(ServerList, animated: true)
    }
    func pushFolderList() {
        
        self.navigationController?.pushViewController(FolderList, animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(orbotStatus),
                                               name: .orbotStatus, object: nil)
        settingsViewModel.delegate = self
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        if #available(iOS 14.0, *) {
            let settingsView = SettingsView().environmentObject(settingsViewModel)
            let hostingController = UIHostingController(rootView: settingsView)
            
            addChild(hostingController)
            view.addSubview(hostingController.view)
            
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            
            hostingController.didMove(toParent: self)
            hostingController.view.backgroundColor = .clear
            view.backgroundColor = .clear
        } else {
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .orbotStatus, object: nil)
    }
    
    @objc
    func orbotStatus(notification: Notification) {
        DispatchQueue.main.async {
            self.settingsViewModel.objectWillChange.send()
        }
    }
}
protocol GeneralSettingsDelegate: AnyObject {
    func pushServerListScreen()
}

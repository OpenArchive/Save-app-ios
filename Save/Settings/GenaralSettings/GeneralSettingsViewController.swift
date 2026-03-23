
import UIKit
import SwiftUI
import YapDatabase
class GeneralSettingsViewController:UIViewController,ViewControllerNavigationDelegate {
    
    private lazy var ServerList: ServerListViewController = {
        let vc = ServerListViewController()
        return vc
    }()
   
    private lazy var FolderList: FolderListNewViewController = {
        let vc = FolderListNewViewController(archived: true)
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
        
        
        settingsViewModel.delegate = self
        // Set empty title for back button (chevron only)
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
    
    override func viewDidAppear(_ animated: Bool) {
        trackScreenViewSafely("Settings")
    }
    
}
protocol GeneralSettingsDelegate: AnyObject {
    func pushServerListScreen()
}

protocol ViewControllerNavigationDelegate: AnyObject {
    func pushViewController(_ viewController: UIViewController)
    func pushServerList()
    func pushFolderList()
    func pushDetailServer(space:Space)
}

extension ViewControllerNavigationDelegate {
    func pushDetailServer(space:Space) {
        
    }
    func pushServerList(){
        
    }
    func pushFolderList(){
        
    }
    func pushViewController(_ viewController: UIViewController){
        
    }
}

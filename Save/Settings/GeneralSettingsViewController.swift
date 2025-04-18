
import UIKit
import SwiftUI
import YapDatabase
class GeneralSettingsViewController:UIViewController,ViewControllerNavigationDelegate {
    
    private lazy var ServerList: ServerListNewViewController = {
        let vc = ServerListNewViewController()
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
    
}
protocol GeneralSettingsDelegate: AnyObject {
    func pushServerListScreen()
}

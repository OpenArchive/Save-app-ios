//
//  PrivateServerSettingViewController.swift
//  Save
//
//  Created by navoda on 2025-05-26.
//  Copyright © 2025 Open Archive. All rights reserved.
//


import UIKit
import SwiftUI

class StorachaSettingViewController: UIViewController {
   
    private lazy var storachaLoginViewController: StorachaLoginViewController = {
        let vc = StorachaLoginViewController()
        return vc
    }()
    override func viewDidLoad() {
        super.viewDidLoad()

        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem

        if #available(iOS 14.0, *) {
            navigationItem.title = ""

            let settingsView = StorachaSettingView( disableBackAction: { [weak self] isDisabled in
                self?.navigationItem.hidesBackButton = isDisabled
            }, dismissAction: {
              
                self.navigationController?.popViewController(animated: true)
            }, manageAccountsAction: {type in
                if type == "manage" {
                    self.handleManageNavigation()
                }else if(type == "join"){
                    self.manageSpaceNavigation(isNew: true)
                }
                else{
                    self.manageSpaceNavigation(isNew: false)
                }
              
            })

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
        }
    }
    func handleManageNavigation() {
        
        let accounts = UserDefaults.standard.stringArray(forKey: "storedAccounts") ?? []

        if accounts.isEmpty {
            let loginVC = StorachaLoginViewController() 
            self.navigationController?.pushViewController(loginVC, animated: true)
        } else {
            let accountsVC = StorachaAccountsviewController()
            self.navigationController?.pushViewController(accountsVC, animated: true)
        }
    }
    func manageSpaceNavigation(isNew:Bool){
        let store = AccountsStore(initial: AccountsAppState(), reducer: appReducer)
           let storedSpaces: [StorachaSpace]

           if let data = UserDefaults.standard.data(forKey: "storedSpaces"),
              let decoded = try? JSONDecoder().decode([StorachaSpace].self, from: data) {
               storedSpaces = decoded
           } else {
               storedSpaces = []
           }

           let targetVC: UIViewController
        if storedSpaces.isEmpty || isNew {
            targetVC = QRCodeViewController(store: store)
           } else {
               targetVC = SpaceListViewController(store: store)
           }

           navigationController?.pushViewController(targetVC, animated: true)
    }
}

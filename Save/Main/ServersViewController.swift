//
//  ServersViewController.swift
//  Save
//
//  Created by navoda on 2024-12-19.
//  Copyright © 2024 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import SwiftUI
protocol ServerListDelegeate {
    func addSpace()
    func selectSpace()
}
class ServersViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {

    @IBOutlet weak var serverListTable: UITableView!
    private var spacesConn = Db.newLongLivedReadConn()

    private var spacesMappings = YapDatabaseViewMappings(
        groups: SpacesView.groups, view: SpacesView.name)
    var delegate: ServerListDelegeate?
    var selectSpace = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Servers", comment: "")
        serverListTable.register(SideMenuItemCell.nib, forCellReuseIdentifier: SideMenuItemCell.reuseId)
        serverListTable.delegate = self
        serverListTable.dataSource = self
        print(spacesMappings)
        spacesConn?.update(mappings: spacesMappings)
        Db.add(observer: self, #selector(yapDatabaseModified))
        addServerButton()
    }
   
    override func viewWillDisappear(_ animated: Bool) {
        if(selectSpace){
            delegate?.selectSpace()
            selectSpace = false
        }
    }

    // MARK: UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
      
        return Int(spacesMappings.numberOfSections())
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
//        if section >= spacesMappings.numberOfSections() {
//            return 1
//        }

        return Int(spacesMappings.numberOfItems(inSection: UInt(section)))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SideMenuItemCell.reuseId, for: indexPath) as! SideMenuItemCell

       
//        if indexPath.section >= spacesMappings.numberOfSections() {
//            cell.applyAdd()
//            cell.accessibilityIdentifier = "cellAddAccount"
//        }
//        else {
            let space = getSpace(at: indexPath)
            cell.apply(space, select: SelectedSpace.id == space?.id)
    //    }

        return cell
    }
    func  addServerButton(){
        let floatingButton = UIButton(type: .system)
               floatingButton.setImage(UIImage(systemName: "plus"), for: .normal) // "+" icon
               floatingButton.tintColor = .white // Icon color
        if #available(iOS 15.0, *) {
            floatingButton.backgroundColor = UIColor.systemMint
        } else {
            floatingButton.backgroundColor = UIColor.systemTeal
        } // Button background color
               floatingButton.layer.cornerRadius = 30 // Make it circular
               floatingButton.layer.shadowColor = UIColor.black.cgColor
               floatingButton.layer.shadowOffset = CGSize(width: 0, height: 2)
               floatingButton.layer.shadowOpacity = 0.3
               floatingButton.layer.shadowRadius = 5

               // Add Action
               floatingButton.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)

               // Add to View
               view.addSubview(floatingButton)

               // Set Constraints
               floatingButton.translatesAutoresizingMaskIntoConstraints = false
               NSLayoutConstraint.activate([
                   floatingButton.widthAnchor.constraint(equalToConstant: 60),
                   floatingButton.heightAnchor.constraint(equalToConstant: 60),
                   floatingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), // 20pt from the right
                   floatingButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)    // 20pt from the bottom
               ])
    }
    @objc func floatingButtonTapped() {
           print("Floating button tapped!")
        delegate?.addSpace()
                  }
    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//         if indexPath.section >= spacesMappings.numberOfSections() {
//            delegate?.addSpace()
//        }
//        else {
            SelectedSpace.space = getSpace(at: indexPath)
            SelectedSpace.store()
            selectSpace = true
            navigationController?.popViewController(animated: false)
            
            // Create the SwiftUI view
//            let folderView = FolderList()
//                 
//                 // Embed it in a UIHostingController
//                 let hostingController = UIHostingController(rootView: folderView)
//            hostingController.navigationItem.title = "Folders"
//                 // Push the hosting controller onto the navigation stack
//                 navigationController?.pushViewController(hostingController, animated: true)
  //      }
    }

    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Shall be called, when something changes the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        if spacesConn?.hasChanges(spacesMappings) ?? false {
            serverListTable.reloadData()
        }
    }

    private func getSpace(at indexPath: IndexPath) -> Space? {
        spacesConn?.object(at: indexPath, in: spacesMappings)
    }

    
}

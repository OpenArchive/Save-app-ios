//
//  AddFolderViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 20.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class AddFolderViewController: BaseViewController {

    var noBrowse: Bool {
        SelectedSpace.space is IaSpace
    }


    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString("Add a Folder", comment: "")
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString("Select where to \nstore your media.", comment: "")
        }
    }

    @IBOutlet weak var emptyView: UIView!
    
    convenience init() {
        self.init(nibName: "AddFolderViewController", bundle: nil)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Add a Folder", comment: "")
        if noBrowse,
           var stack = navigationController?.viewControllers
        {
            stack.removeAll { $0 is AddFolderViewController }
            stack.append(AddNewFolderViewController())
            navigationController?.setViewControllers(stack, animated: false)

            return
        }
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
               navigationItem.backBarButtonItem = backBarButtonItem
        

        let button1 = BigButton.create(
            icon: UIImage(named: "add_new_folder"),
            title: NSLocalizedString("Create a New Folder", comment: ""),
            target: self,
            
            action: #selector(createNew),
            container: view,
            above: emptyView)

        BigButton.create(
            icon: UIImage(named: "browse_folder"),
            title: NSLocalizedString("Browse Existing Folders", comment: ""),
            target: self,
            action: #selector(browse),
            container: view,
            above: button1,
            equalHeight: true)
    }


    @IBAction func createNew() {
        navigationController?.pushViewController(AddNewFolderViewController(), animated: true)
    }

    @IBAction func browse() {
        navigationController?.pushViewController(BrowseViewController(), animated: true)
    }
}

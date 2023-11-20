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
        SelectedSpace.space is IaSpace || SelectedSpace.space is DropboxSpace
    }


    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString("Add a Folder", comment: "")
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString("Select where to store your media", comment: "")
        }
    }

    @IBOutlet weak var newBt: UIView!

    @IBOutlet weak var newLb: UILabel! {
        didSet {
            newLb.text = NSLocalizedString("Create a New Folder", comment: "")
        }
    }


    @IBOutlet weak var browseBt: UIView!

    @IBOutlet weak var broweLb: UILabel! {
        didSet {
            broweLb.text = NSLocalizedString("Browse Existing Folders", comment: "")
        }
    }


    convenience init() {
        self.init(nibName: "AddFolderViewController", bundle: nil)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        // We cannot browse the Internet Archive.
        // We cannot browse Dropbox in the app extension.
        // So show NewProjectViewController immediately instead of this scene.
        if noBrowse,
           var stack = navigationController?.viewControllers
        {
            stack.removeAll { $0 is AddFolderViewController }
            stack.append(NewFolderViewController())
            navigationController?.setViewControllers(stack, animated: false)

            return
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))
    }


    @IBAction func createNew() {
        navigationController?.pushViewController(NewFolderViewController(), animated: true)
    }

    @IBAction func browse() {
        navigationController?.pushViewController(BrowseViewController(), animated: true)
    }
}

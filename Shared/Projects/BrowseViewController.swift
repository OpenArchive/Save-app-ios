//
//  BrowseViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider

protocol BrowseDelegate {
    func didSelect(name: String)
}

class BrowseViewController: BaseTableViewController {

    var delegate: BrowseDelegate?

    private var provider: WebDAVFileProvider? {
        return (SelectedSpace.space as? WebDavSpace)?.provider
    }

    private var loading = true

    private var error: Error?

    private var folders = [FileObject]()

    private var selected: Int?


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Browse Projects".localize()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem?.isEnabled = false

        tableView.register(FolderCell.nib, forCellReuseIdentifier: FolderCell.reuseId)

        loadFolders()
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section > 0 {
            return error == nil ? 0 : 1
        }

        return folders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId,
                                                 for: indexPath) as! MenuItemCell

            return cell.set(error!)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: FolderCell.reuseId,
                                                 for: indexPath) as! FolderCell

        cell.set(folder: folders[indexPath.row])

        cell.accessoryType = indexPath.row == selected ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section > 0 || error != nil {
            return nil
        }

        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var rows = [indexPath]

        if let selected = selected {
            rows.append(IndexPath.init(row: selected, section: indexPath.section))
        }

        selected = indexPath.row
        navigationItem.rightBarButtonItem?.isEnabled = true

        tableView.reloadRows(at: rows, with: .none)
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }


    // MARK: Private Methods

    private func beginWork(_ block: () -> Void) {
        loading = true
        error = nil

        DispatchQueue.main.async {
            self.workingOverlay.isHidden = false
        }

        block()
    }

    private func endWork(_ error: Error?) {
        self.loading = false
        self.error = error

        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.workingOverlay.isHidden = true
        }
    }

    private func loadFolders() {
        beginWork {
            folders.removeAll()

            provider?.contentsOfDirectory(path: "") { files, error in
                for file in files {
                    if file.isDirectory {
                        self.folders.append(file)
                    }
                }

                self.endWork(error)
            }
        }
    }

    @objc private func done() {
        guard let selected = selected else {
            return
        }

        // The NewProjectViewController will animate back, also.
        // So, no animation here. Mind the execution order of the callback!
        navigationController?.popViewController(animated: false)

        delegate?.didSelect(name: folders[selected].name)
    }
}

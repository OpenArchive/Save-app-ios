//
//  BrowseViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class BrowseViewController: BaseTableViewController {

    class Folder {
        let name: String

        let modifiedDate: Date?

        let original: Any?

        init(_ name: String, _ modifiedDate: Date?, _ original: Any?) {
            self.name = name
            self.modifiedDate = modifiedDate
            self.original = original
        }

        convenience init(_ original: FileInfo) {
            self.init(original.name, original.modifiedDate ?? original.creationDate, original)
        }
    }

    private var loading = true

    private var error: Error?

    var folders = [Folder]()

    private var selected: Int?


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Browse Projects", comment: "")
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
            rows.append(IndexPath(row: selected, section: indexPath.section))
        }

        selected = indexPath.row
        navigationItem.rightBarButtonItem?.isEnabled = true

        tableView.reloadRows(at: rows, with: .none)
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section > 0 ? MenuItemCell.height : FolderCell.height
    }


    // MARK: Public Methods

    func beginWork(_ block: () -> Void) {
        loading = true
        error = nil

        DispatchQueue.main.async {
            self.workingOverlay.isHidden = false
        }

        block()
    }

    func endWork(_ error: Error?) {
        self.loading = false
        self.error = error

        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.workingOverlay.isHidden = true
        }
    }

    func loadFolders() {
        beginWork {
            folders.removeAll()

            if let space = SelectedSpace.space as? WebDavSpace, let url = space.url {
                space.session.info(url) { info, error in
                    let files = info.dropFirst().sorted(by: {
                        $0.modifiedDate ?? $0.creationDate ?? Date(timeIntervalSince1970: 0)
                        > $1.modifiedDate ?? $1.creationDate ?? Date(timeIntervalSince1970: 0)
                    })

                    for file in files {
                        if file.type == .directory && !file.isHidden {
                            self.folders.append(Folder(file))
                        }
                    }

                    self.endWork(error)
                }
            }
            else {
                self.endWork(nil)
            }
        }
    }


    // MARK: Private Methods

    @objc private func done() {
        guard let selected = selected,
            let space = SelectedSpace.space else {
            return
        }

        let alert = DuplicateProjectAlert(nil)

        if alert.exists(spaceId: space.id, name: folders[selected].name) {
            present(alert, animated: true)
            return
        }

        let project = Project(name: folders[selected].name, space: space)

        Db.writeConn?.asyncReadWrite() { transaction in
            transaction.setObject(project, forKey: project.id,
                                  inCollection: Project.collection)
        }

        dismiss(animated: true)
    }
}

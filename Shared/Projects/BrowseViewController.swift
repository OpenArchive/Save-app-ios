//
//  BrowseViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 30.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import FilesProvider
import SwiftyDropbox

class BrowseViewController: BaseTableViewController {

    class Folder {
        let name: String

        let modifiedDate: Date?

        let original: Any?

        init(_ original: FileObject) {
            name = original.name
            modifiedDate = original.modifiedDate ?? original.creationDate
            self.original = original
        }

        init(_ original: Files.FolderMetadata) {
            name = original.name
            modifiedDate = nil
            self.original = original
        }
    }

    private var provider: WebDAVFileProvider? {
        return (SelectedSpace.space as? WebDavSpace)?.provider
    }

    private var dropboxClient: DropboxClient? {
        if let client = DropboxClientsManager.authorizedClient {
            return client
        }

        if let accessToken = (SelectedSpace.space as? DropboxSpace)?.password {
            return DropboxClient(accessToken: accessToken)
        }

        return nil
    }

    private var loading = true

    private var error: Error?

    private var folders = [Folder]()

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

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section > 0 ? MenuItemCell.height : FolderCell.height
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

            if let provider = provider {
                provider.contentsOfDirectory(path: "") { files, error in
                    for file in files.sort(by: .modifiedDate, ascending: false, isDirectoriesFirst: true) {
                        if file.isDirectory {
                            self.folders.append(Folder(file))
                        }
                    }

                    self.endWork(error)
                }
            }
            else if let client = dropboxClient {
                client.files.listFolder(path: "", includeNonDownloadableFiles: false)
                    .response(completionHandler: dropboxCompletionHandler)
            }
            else {
                self.endWork(nil)
            }
        }
    }

    private func dropboxCompletionHandler<T: CustomStringConvertible>(_ result: Files.ListFolderResult?, _ error: CallError<T>?) {
        if let error = error {
            print("[\(String(describing: type(of: self)))] error=\(error)")

            return self.endWork(NSError(
                domain: String(describing: type(of: error)),
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.description]))
        }

        for entry in result?.entries ?? [] {
            if let entry = entry as? Files.FolderMetadata {
                self.folders.append(Folder(entry))
            }
        }

        if result?.hasMore ?? false {
            dropboxClient?.files.listFolderContinue(cursor: result!.cursor)
                .response(completionHandler: dropboxCompletionHandler)
        }
        else {
            self.endWork(nil)
        }
    }

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

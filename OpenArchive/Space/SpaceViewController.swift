//
//  SpaceViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 15.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import Localize
import YapDatabase

class SpaceViewController: BaseTableViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    private weak var collectionView: UICollectionView?

    private lazy var spacesReadConn = Db.newLongLivedReadConn()

    private lazy var spacesMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: SpacesView.groups,
                                               view: SpacesView.name)

        spacesReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private var spacesCount: Int {
        return Int(spacesMappings.numberOfItems(inSection: 0))
    }

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: ProjectsView.groups,
                                               view: ProjectsView.name)

        projectsReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private var projectsCount: Int {
        return Int(projectsMappings.numberOfItems(inSection: 0))
    }

    /**
     Delete action for table list row. Deletes a space.
     */
    private lazy var deleteAction: UITableViewRowAction = {
        let action = UITableViewRowAction(
            style: .destructive,
            title: "Delete".localize())
        { (action, indexPath) in

            let title = "Delete Project".localize()
            let project = self.getProject(indexPath)
            let message = "Are you sure you want to delete your project \"%\"?".localize(value: project?.name ?? "")
            let handler: AlertHelper.ActionHandler = { _ in
                if let key = project?.id {
                    Db.writeConn?.asyncReadWrite() { transaction in
                        transaction.removeObject(forKey: key, inCollection: Project.collection)
                    }
                }
            }

            AlertHelper.present(
                self, message: message,
                title: title, actions: [
                    AlertHelper.cancelAction(),
                    AlertHelper.destructiveAction("Delete".localize(), handler: handler)
                ])

            self.tableView.setEditing(false, animated: true)
        }

        return action
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                       name: .YapDatabaseModifiedExternally, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        tableView.reloadData()
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 3
        case 1:
            return projectsCount + (SelectedSpace.space is IaSpace ? 1 : 2)
        case 2:
            return 3
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                return SpacesListCell.height
            }
            else if indexPath.row == 1 {
                return SelectedSpaceCell.height
            }
        }

        return MenuItemCell.height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0,
                let cell = tableView.dequeueReusableCell(withIdentifier: SpacesListCell.reuseId) as? SpacesListCell {

                collectionView = cell.collectionView
                collectionView?.delegate = self
                collectionView?.dataSource = self

                return cell
            }
            else if indexPath.row == 1,
                let cell = tableView.dequeueReusableCell(withIdentifier: SelectedSpaceCell.reuseId) as? SelectedSpaceCell {

                cell.space = SelectedSpace.space
                return cell
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell
        
        switch indexPath.section {
        case 0:
            return cell.set("Profile".localize())

        case 1:
            if indexPath.row < projectsCount {
                return cell.set(getProject(indexPath)?.name ?? "Unnamed Project".localize())
            }
            else if indexPath.row == projectsCount {
                return cell.set("Create New Project".localize(), isPlaceholder: true)
            }

            return cell.set("Browse".localize(), UIColor.accent, true)

        case 2:
            cell.addIndicator.isHidden = true
            switch indexPath.row {
            case 0:
                return cell.set("Data Use".localize())
            case 1:
                return cell.set("Privacy".localize())
            default:
                return cell.set("About".localize())
            }

        default:
            return cell.set("")
        }
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> TableHeader {
        let header = super.tableView(tableView, viewForHeaderInSection: section)

        switch section {
        case 1:
            header.text = "Projects".localize()
        case 2:
            header.text = "Info".localize()
        default:
            break
        }

        return header
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row < projectsCount
    }

    override public func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var vc: UIViewController?

        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                if let space = SelectedSpace.space as? IaSpace {
                    let iavc = InternetArchiveViewController()
                    iavc.space = space
                    vc = iavc
                }
                else if let space = SelectedSpace.space as? WebDavSpace {
                    let psvc = PrivateServerViewController()
                    psvc.space = space
                    vc = psvc
                }
            }
            else if indexPath.row == 2 {
                vc = EditProfileViewController()
            }

        case 1:
            if indexPath.row < projectsCount {
                vc = ProjectViewController(getProject(indexPath)!)
            }
            else if indexPath.row == projectsCount {
                vc = ProjectViewController()
            }
            else {
                performSegue(withIdentifier: "browseSegue", sender: self)
            }

        default:
            break
        }

        if let vc = vc {
            navigationController?.pushViewController(vc, animated: true)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return spacesCount + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "spaceCell", for: indexPath) as! SpaceCell

        if indexPath.row < spacesCount {
            cell.space = getSpace(indexPath)
        }
        else {
            cell.setAdd()
        }

        return cell
    }


    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row < spacesCount {
            SelectedSpace.space = getSpace(indexPath)
            tableView.reloadData()
        }
        else {
            performSegue(withIdentifier: "connectSpaceSegue", sender: self)
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        var changes = NSArray()

        (spacesReadConn?.ext(SpacesView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(nil,
                               rowChanges: &changes,
                               for: spacesReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: spacesMappings)

        if let changes = changes as? [YapDatabaseViewRowChange],
            changes.count > 0 {

            collectionView?.performBatchUpdates({
                for change in changes {
                    switch change.type {
                    case .insert:
                        if let newIndexPath = change.newIndexPath {
                            collectionView?.insertItems(at: [newIndexPath])
                        }
                    case .delete:
                        if let indexPath = change.indexPath {
                            collectionView?.deleteItems(at: [indexPath])
                        }
                    case .move:
                        if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                            collectionView?.moveItem(at: indexPath, to: newIndexPath)
                        }
                    case .update:
                        if let indexPath = change.indexPath {
                            collectionView?.reloadItems(at: [indexPath])
                        }
                    }
                }
            })
        }

        var sectionChanges = NSArray()
        changes = NSArray()

        (projectsReadConn?.ext(ProjectsView.name) as? YapDatabaseViewConnection)?
            .getSectionChanges(&sectionChanges,
                               rowChanges: &changes,
                               for: projectsReadConn?.beginLongLivedReadTransaction() ?? [],
                               with: projectsMappings)

        if let changes = changes as? [YapDatabaseViewRowChange],
            changes.count > 0 {

            tableView.beginUpdates()

            for change in changes {
                switch change.type {
                case .delete:
                    if let indexPath = change.indexPath {
                        tableView.deleteRows(at: [transform(indexPath)], with: .automatic)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath {
                        tableView.insertRows(at: [transform(newIndexPath)], with: .automatic)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                        tableView.moveRow(at: transform(indexPath), to: transform(newIndexPath))
                    }
                case .update:
                    if let indexPath = change.indexPath {
                        tableView.reloadRows(at: [transform(indexPath)], with: .none)
                    }
                }
            }

            tableView.endUpdates()
        }
    }

    /**
     Callback for `YapDatabaseModifiedExternally` notification.

     Will be called, when something outside the process (e.g. in the share extension) changed
     the database.
     */
    @objc func yapDatabaseModifiedExternally(notification: Notification) {
        spacesReadConn?.beginLongLivedReadTransaction()

        spacesReadConn?.read { transaction in
            self.spacesMappings.update(with: transaction)
            self.collectionView?.reloadData()
        }

        projectsReadConn?.beginLongLivedReadTransaction()

        projectsReadConn?.read { transaction in
            self.projectsMappings.update(with: transaction)
            self.tableView.reloadData()
        }
    }


    // MARK: Private Methods

    private func getSpace(_ indexPath: IndexPath) -> Space? {
        var space: Space?

        spacesReadConn?.read() { transaction in
            space = (transaction.ext(SpacesView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(indexPath.row), inSection: 0, with: self.spacesMappings) as? Space
        }

        return space
    }

    private func getProject(_ indexPath: IndexPath) -> Project? {
        var project: Project?

        projectsReadConn?.read() { transaction in
            project = (transaction.ext(ProjectsView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(indexPath.row), inSection: 0, with: self.projectsMappings) as? Project
        }

        return project
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: 1)
    }
}

//
//  TableWithSpacesViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase

class TableWithSpacesViewController: BaseTableViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    private weak var collectionView: UICollectionView?

    private lazy var spacesReadConn = Db.newLongLivedReadConn()

    private lazy var spacesMappings = YapDatabaseViewMappings(
        groups: SpacesView.groups, view: SpacesView.name)

    private var spacesCount: Int {
        return Int(spacesMappings.numberOfItems(inSection: 0))
    }

    var allowAdd = false

    override func viewDidLoad() {
        super.viewDidLoad()

        spacesReadConn?.update(mappings: spacesMappings)

        tableView.register(SpacesListCell.nib, forCellReuseIdentifier: SpacesListCell.reuseId)
        tableView.register(SelectedSpaceCell.nib, forCellReuseIdentifier: SelectedSpaceCell.reuseId)
    }

    // MARK: Public Methods

    func getSpacesListCell() -> SpacesListCell? {
        let cell = tableView.dequeueReusableCell(withIdentifier: SpacesListCell.reuseId) as? SpacesListCell

        collectionView = cell?.collectionView
        collectionView?.register(SpaceCell.nib, forCellWithReuseIdentifier: SpaceCell.reuseId)
        collectionView?.delegate = self
        collectionView?.dataSource = self

        return cell
    }

    func getSelectedSpaceCell() -> SelectedSpaceCell? {
        let cell = tableView.dequeueReusableCell(withIdentifier: SelectedSpaceCell.reuseId) as? SelectedSpaceCell
        cell?.space = SelectedSpace.space

        return cell
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return spacesCount + (allowAdd ? 1 : 0)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SpaceCell.reuseId, for: indexPath) as! SpaceCell

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
            SelectedSpace.store()
            tableView.reloadData()
        }
        else {
            performSegue(withIdentifier: "connectSpaceSegue", sender: self)
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Shall be called, when something changes the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        guard let notifications = spacesReadConn?.beginLongLivedReadTransaction(),
            let viewConn = spacesReadConn?.ext(SpacesView.name) as? YapDatabaseViewConnection else {
            return
        }

        if !viewConn.hasChanges(for: notifications) {
            spacesReadConn?.update(mappings: spacesMappings)

            return
        }

        let (_, changes) = viewConn.getChanges(forNotifications: notifications, withMappings: spacesMappings)

        if changes.count > 0 {
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
                    @unknown default:
                        break
                    }
                }
            })
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
}

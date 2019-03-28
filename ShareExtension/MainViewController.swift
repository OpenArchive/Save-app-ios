//
//  MainViewController.swift
//  ShareExtension
//
//  Created by Benjamin Erhart on 03.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import YapDatabase
import MobileCoreServices
import MBProgressHUD

@objc(MainViewController)
class MainViewController: TableWithSpacesViewController {

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings: YapDatabaseViewMappings = {
        let mappings = YapDatabaseViewMappings(groups: ActiveProjectsView.groups,
                                               view: ActiveProjectsView.name)

        projectsReadConn?.read { transaction in
            mappings.update(with: transaction)
        }

        return mappings
    }()

    private var projectsCount: Int {
        return Int(projectsMappings.numberOfItems(inSection: 0))
    }

    private lazy var providerOptions = {
        return [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: AssetFactory.thumbnailSize)]
    }()

    private var progress = Progress()

    private lazy var hud: MBProgressHUD = {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.minShowTime = 1
        hud.label.text = "Adding…".localize()
        hud.mode = .determinate
        hud.progressObject = progress

        return hud
    }()

    private var selectedRow = -1


    override func viewDidLoad() {
        Db.setup()

        view.tintColor = UIColor.accent

        super.viewDidLoad()

        tableView.register(TitleCell.self, forCellReuseIdentifier: TitleCell.reuseId)
        tableView.register(ButtonCell.self, forCellReuseIdentifier: ButtonCell.reuseId)

        let nc = NotificationCenter.default

        nc.addObserver(self, selector: #selector(yapDatabaseModified),
                       name: .YapDatabaseModified, object: nil)

        nc.addObserver(self, selector: #selector(yapDatabaseModifiedExternally),
                       name: .YapDatabaseModifiedExternally, object: nil)

        // Hovering close button.

        let closeBt = UIButton(type: .custom)
        closeBt.setImage(UIImage(named: "ic_cancel")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeBt.setImage(UIImage(named: "ic_cancel")?.withRenderingMode(.alwaysTemplate), for: .selected)
        closeBt.translatesAutoresizingMaskIntoConstraints = false
        closeBt.layer.zPosition = CGFloat(Int.max)
        closeBt.addTarget(self, action: #selector(done), for: .touchUpInside)

        view.addSubview(closeBt)

        closeBt.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor).isActive = true
        closeBt.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 32).isActive = true
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 3 ? projectsCount : 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return SpacesListCell.height
        case 1:
            return SelectedSpaceCell.height
        case 2:
            return TitleCell.height
        case 4:
            return ButtonCell.height
        default:
            return MenuItemCell.height
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0,
            let cell = getSpacesListCell() {

            return cell
        }
        else if indexPath.section == 1,
            let cell = getSelectedSpaceCell() {

            cell.selectionStyle = .none
            cell.centered()

            return cell
        }
        else if indexPath.section == 2,
            let cell = tableView.dequeueReusableCell(withIdentifier: TitleCell.reuseId, for: indexPath) as? TitleCell {

            cell.textLabel?.text = "Choose a Project".localize()

            return cell
        }
        else if indexPath.section == 4,
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.reuseId, for: indexPath) as? ButtonCell {

            cell.textLabel?.text = "Import".localize()

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell

        if indexPath.section == 3 {
            cell.accessoryType = selectedRow == indexPath.row ? .checkmark : .none

            return cell.set(getProject(indexPath)?.name ?? "Unnamed Project".localize())
        }

        return cell.set("")
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }


    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath.section > 2 ? indexPath : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 {
            selectedRow = indexPath.row

            var allProjects = [IndexPath]()

            for r in 1 ... tableView.numberOfRows(inSection: indexPath.section) {
                allProjects.append(IndexPath(row: r - 1, section: indexPath.section))
            }

            tableView.reloadRows(at: allProjects, with: .automatic)

            return
        }

        let project = getProject(selectedRow)

        guard let items = extensionContext?.inputItems as? [NSExtensionItem],
            let collection = project?.currentCollection else {

            return
        }

        hud.show(animated: true)

        for item in items {
            guard let attachments = item.attachments else {
                continue
            }

            for provider in attachments {
                if !provider.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                    continue
                }

                progress.totalUnitCount += 1

                provider.loadPreviewImage(options: providerOptions) { thumbnail, error in
                    provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { item, error in

                        if error != nil {
                            return self.onCompletion(error!)
                        }

                        guard let url = item as? URL else {
                            return self.onCompletion(error: "Couldn't acquire item!".localize())
                        }

                        AssetFactory.create(fromFileUrl: url,
                                            thumbnail: thumbnail as? UIImage,
                                            collection)
                        { asset in
                            Db.writeConn?.asyncReadWrite() { transaction in
                                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)

                                self.onCompletion()
                            }
                        }
                    }
                }
            }
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` notification.

     Will be called, when something inside the process changed the database.
     */
    @objc override func yapDatabaseModified(notification: Notification) {
        super.yapDatabaseModified(notification: notification)

        var sectionChanges = NSArray()
        var changes = NSArray()

        (projectsReadConn?.ext(ActiveProjectsView.name) as? YapDatabaseViewConnection)?
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
                        if selectedRow == indexPath.row {
                            selectedRow = -1
                        }

                        tableView.deleteRows(at: [transform(indexPath)], with: .automatic)
                    }
                case .insert:
                    if let newIndexPath = change.newIndexPath {
                        if selectedRow == newIndexPath.row {
                            selectedRow = -1
                        }

                        tableView.insertRows(at: [transform(newIndexPath)], with: .automatic)
                    }
                case .move:
                    if let indexPath = change.indexPath, let newIndexPath = change.newIndexPath {
                        if selectedRow == indexPath.row {
                            selectedRow = newIndexPath.row
                        }

                        tableView.moveRow(at: transform(indexPath), to: transform(newIndexPath))
                    }
                case .update:
                    if let indexPath = change.indexPath {
                        if selectedRow == indexPath.row {
                            selectedRow = -1
                        }

                        tableView.reloadRows(at: [transform(indexPath)], with: .none)
                    }
                @unknown default:
                    break
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
    @objc override func yapDatabaseModifiedExternally(notification: Notification) {
        super.yapDatabaseModifiedExternally(notification: notification)

        projectsReadConn?.beginLongLivedReadTransaction()

        projectsReadConn?.read { transaction in
            self.projectsMappings.update(with: transaction)
        }

        tableView.reloadData()
    }


    // MARK: Actions

    /**
     Inform the host that we're done, so it un-blocks its UI.
     */
    @objc func done() {
        extensionContext?.completeRequest(returningItems: nil)
    }


    // MARK: Private Methods

    private func getProject(_ row: Int) -> Project? {
        var project: Project?

        projectsReadConn?.read() { transaction in
            project = (transaction.ext(ActiveProjectsView.name) as? YapDatabaseViewTransaction)?
                .object(atRow: UInt(row), inSection: 0, with: self.projectsMappings) as? Project
        }

        return project
    }

    private func getProject(_ indexPath: IndexPath) -> Project? {
        return getProject(indexPath.row)
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: 3)
    }

    /**
     Completion callback for MXRoom#send[...] operations.

     - Show error message, if any.
     - Increase progress count.
     - Leave ShareViewController, if done.
     - Delay leave by 5 seconds, when error happened.

     - parameter error: An optional localized error string to show to the user.
     */
    private func onCompletion(_ error: Error) {
        onCompletion(error: error.localizedDescription)
    }

    /**
     Callback for when done with handling an item.

     - Show error message, if any.
     - Increase progress count.
     - Leave ShareViewController, if done.
     - Delay leave by 5 seconds, when error happened.

     - parameter error: An optional localized error string to show to the user.
     */
    private func onCompletion(error: String? = nil) {
        if let error = error {
            DispatchQueue.main.async {
                self.hud.detailsLabel.text = error
            }
        }

        progress.completedUnitCount += 1

        if progress.completedUnitCount == progress.totalUnitCount {
            DispatchQueue.main.async {
                self.hud.label.text = "Go to the app to upload!".localize()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.done()
            }
        }
    }
}

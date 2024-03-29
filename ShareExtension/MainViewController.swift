//
//  MainViewController.swift
//  ShareExtension
//
//  Created by Benjamin Erhart on 03.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

import UIKit
import UserNotifications
import YapDatabase
import LegacyUTType
import MBProgressHUD

@objc(MainViewController)
class MainViewController: TableWithSpacesViewController {

    private static let projectSection = 3

    private lazy var projectsReadConn = Db.newLongLivedReadConn()

    private lazy var projectsMappings = YapDatabaseViewMappings(
        groups: ActiveProjectsView.groups, view: ActiveProjectsView.name)

    private var projectsCount: Int {
        return Int(projectsMappings.numberOfItems(inSection: 0))
    }

    private lazy var providerOptions = {
        return [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: AssetFactory.thumbnailSize)]
    }()

    private var progress = Progress()

    private var successfulItems = 0

    private lazy var hud: MBProgressHUD = {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.minShowTime = 1
        hud.label.text = NSLocalizedString("Adding…", comment: "")
        hud.mode = .determinate
        hud.progressObject = progress

        return hud
    }()

    private var selectedRow = -1
    private var project: Project?

    private var notificationsAllowed = false


    override func viewDidLoad() {
        Db.setup()

        projectsReadConn?.update(mappings: projectsMappings)

        view.tintColor = .accent

        UIFont.setUpMontserrat()

        super.viewDidLoad()

        tableView.register(TitleCell.nib, forCellReuseIdentifier: TitleCell.reuseId)
        tableView.register(ButtonCell.self, forCellReuseIdentifier: ButtonCell.reuseId)

        Db.add(observer: self, #selector(yapDatabaseModified))

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

        UNUserNotificationCenter.current().requestAuthorization(options: .alert) { granted, error in
            self.notificationsAllowed = granted
        }
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == MainViewController.projectSection ? projectsCount + 1 : 1
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

            return cell
        }
        else if indexPath.section == 2,
            let cell = tableView.dequeueReusableCell(withIdentifier: TitleCell.reuseId, for: indexPath) as? TitleCell {

            return cell.set(NSLocalizedString("Choose a Project", comment: ""))
        }
        else if indexPath.section == 4,
            let cell = tableView.dequeueReusableCell(withIdentifier: ButtonCell.reuseId, for: indexPath) as? ButtonCell {

            cell.textLabel?.text = NSLocalizedString("Import", comment: "")

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MenuItemCell.reuseId, for: indexPath) as! MenuItemCell

        if indexPath.section == MainViewController.projectSection {
            if indexPath.row < projectsCount {
                return cell.set(Project.getName(getProject(indexPath)),
                                accessoryType: selectedRow == indexPath.row ? .checkmark : .none)
            }
            else {
                return cell.set(NSLocalizedString("New Project", comment: ""), isPlaceholder: true)
            }
        }

        return cell.set("")
    }


    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return TableHeader.reducedHeight
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return section == 3 ? tableView.separatorView : UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 4 ? 24 : 1
    }


    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath.section > 2 ? indexPath : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == MainViewController.projectSection {
            if indexPath.row >= projectsCount {
                let vc = UINavigationController(rootViewController:
                    AddFolderViewController())
                vc.view.tintColor = .accent
                vc.modalPresentationStyle = .popover
                vc.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                vc.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)

                present(vc, animated: true)

                tableView.deselectRow(at: indexPath, animated: false)

                return
            }


            selectedRow = indexPath.row

            var allProjects = [IndexPath]()

            for r in 1 ... tableView.numberOfRows(inSection: indexPath.section) {
                allProjects.append(IndexPath(row: r - 1, section: indexPath.section))
            }

            tableView.reloadRows(at: allProjects, with: .automatic)

            return
        }

        project = getProject(selectedRow)

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
                if !provider.hasItemConformingToTypeIdentifier(LegacyUTType.data.identifier) {
                    continue
                }

                progress.totalUnitCount += 1

                provider.loadPreviewImage(options: providerOptions) { thumbnail, error in
                    provider.loadItem(forTypeIdentifier: LegacyUTType.data.identifier, options: nil) { item, error in

                        if let error = error {
                            return self.onCompletion(error)
                        }

                        let error = NSLocalizedString("Couldn't import item!", comment: "")

                        if let url = item as? URL {
                            AssetFactory.create(fromFileUrl: url,
                                                thumbnail: thumbnail as? UIImage,
                                                collection)
                            { asset in
                                self.onCompletion(error: asset == nil ? error : nil)
                            }

                            return
                        }

                        if let image = (item as? UIImage)?.jpegData(compressionQuality: 1) {
                            AssetFactory.create(from: image,
                                                uti: LegacyUTType.jpeg,
                                                name: provider.suggestedName,
                                                thumbnail: thumbnail as? UIImage,
                                                collection)
                            { asset in
                                self.onCompletion(error: asset == nil ? error : nil)
                            }

                            return
                        }

                        if let data = item as? Data {
                            AssetFactory.create(from: data,
                                                uti: LegacyUTType.data,
                                                name: provider.suggestedName,
                                                thumbnail: thumbnail as? UIImage,
                                                collection)
                            { asset in
                                debugPrint("[\(String(describing: type(of: self)))] asset=\(asset?.description ?? "(nil)")")
                                self.onCompletion(error: asset == nil ? error : nil)
                            }

                            return
                        }

                        return self.onCompletion(error: error)
                    }
                }
            }
        }
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc override func yapDatabaseModified(notification: Notification) {
        super.yapDatabaseModified(notification: notification)

        if projectsReadConn?.hasChanges(projectsMappings) ?? false {
            tableView.reloadSections([Self.projectSection], with: .automatic)
        }
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
        projectsReadConn?.object(at: IndexPath(row: row, section: 0), in: projectsMappings)
    }

    private func getProject(_ indexPath: IndexPath) -> Project? {
        getProject(indexPath.row)
    }

    private func transform(_ indexPath: IndexPath) -> IndexPath {
        IndexPath(row: indexPath.row, section: indexPath.section + MainViewController.projectSection)
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
        onCompletion(error: error.friendlyMessage)
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
        var showLonger = false

        if let error = error {
            showLonger = true

            DispatchQueue.main.async {
                self.hud.detailsLabel.text = error
            }
        }
        else {
            successfulItems += 1
        }

        progress.completedUnitCount += 1

        if progress.completedUnitCount == progress.totalUnitCount {
            showNotification()

            showLonger = showLonger // last asset had an error
                || !notificationsAllowed // user didn't allow notifications, so show text in HUD instead
                || !(hud.detailsLabel.text?.isEmpty ?? true) // earlier asset had an error

            DispatchQueue.main.asyncAfter(deadline: .now() + (showLonger ? 5 : 0.5)) {
                self.done()
            }
        }
    }

    private func showNotification() {
        guard successfulItems > 0 else {
            // If only errors happened, the HUD will currently show an error, anyway.
            // So no need to display a notification.
            return
        }

        if notificationsAllowed {
            let content = UNMutableNotificationContent()

            content.body = String.localizedStringWithFormat(
                NSLocalizedString("You have %1$u item(s) ready to upload to \"%2$@\".", comment: "#bc-ignore!"),
                successfulItems, Project.getName(project))

            content.userInfo[Project.collection] = project?.id

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

            let request = UNNotificationRequest(identifier: "OpenArchive_notification_id",
                                                content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
        else {
            DispatchQueue.main.async {
                self.hud.label.text = NSLocalizedString("Go to the app to upload!", comment: "")
            }
        }
    }
}

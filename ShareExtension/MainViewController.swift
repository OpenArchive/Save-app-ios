//
//  MainViewController.swift
//  ShareExtension
//
//  Created by Benjamin Erhart on 03.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

// UI migration: Share extension remains UIKit + UITableView + XIB cells; a SwiftUI rewrite is a separate, deferred effort.
import UIKit
import SwiftUI
import UserNotifications
import YapDatabase
import LegacyUTType
import MBProgressHUD

@objc(MainViewController)
class MainViewController: TableWithSpacesViewController {

    private static let projectSection = 3

    /// Explicit UTI allowlist — mirrors the Info.plist activation rule.
    private static let allowedUTIs: Set<String> = [
        "public.jpeg", "public.png", "public.gif", "com.compuserve.gif",
        "public.heic", "public.heif", "public.tiff", "public.bmp",
        "public.mpeg-4", "com.apple.quicktime-movie", "public.avi",
        "public.mpeg", "public.webm", "public.3gpp",
        "public.mp3", "public.aac-audio", "public.flac",
        "org.xiph.ogg", "com.microsoft.waveform-audio", "public.opus",
        "com.adobe.pdf"
    ]

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
    private var passcodeGatePresented = false


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

        // Hide sensitive content until the passcode gate is cleared.
        if shareExtensionPasscodeIsSet() {
            tableView.isHidden = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showPasscodeGateIfNeeded()
    }

    private func showPasscodeGateIfNeeded() {
        guard !passcodeGatePresented, shareExtensionPasscodeIsSet() else { return }
        passcodeGatePresented = true

        let passcodeView = ShareExtensionPasscodeView(
            onSuccess: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.tableView.isHidden = false
                }
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(
                    withError: NSError(
                        domain: NSCocoaErrorDomain,
                        code: NSUserCancelledError,
                        userInfo: nil
                    )
                )
            }
        )

        let host = UIHostingController(rootView: passcodeView)
        host.view.tintColor = .accent  // propagate app teal → Color.accentColor in SwiftUI
        host.modalPresentationStyle = .overFullScreen
        present(host, animated: false)
    }


    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == MainViewController.projectSection ? max(projectsCount, 1) : 1
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
            if projectsCount == 0 {
                return cell.set(NSLocalizedString("No projects. Add one in the app.", comment: ""),
                                textColor: .lightGray)
            }
            return cell.set(Project.getName(getProject(indexPath)),
                            accessoryType: selectedRow == indexPath.row ? .checkmark : .none)
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
        if indexPath.section == MainViewController.projectSection && projectsCount == 0 {
            return nil
        }
        return indexPath.section > 2 ? indexPath : nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == MainViewController.projectSection {
            selectedRow = indexPath.row

            var allProjects = [IndexPath]()

            for r in 1 ... tableView.numberOfRows(inSection: indexPath.section) {
                allProjects.append(IndexPath(row: r - 1, section: indexPath.section))
            }

            tableView.reloadRows(at: allProjects, with: .automatic)

            return
        }

        guard SelectedSpace.space != nil else {
            showAlert(NSLocalizedString("Please select a server first.", comment: ""))
            return
        }

        guard selectedRow >= 0 else {
            showAlert(NSLocalizedString("Please select a project first.", comment: ""))
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
                // Only accept explicitly allowed UTIs — reject arbitrary file types.
                guard let typeIdentifier = Self.allowedUTIs.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                    continue
                }

                progress.totalUnitCount += 1

                provider.loadPreviewImage(options: providerOptions) { thumbnail, error in
                    provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in

                        if let error = error {
                            return self.onCompletion(error)
                        }

                        let error = NSLocalizedString("Couldn't import item!", comment: "")

                        if let url = item as? URL {
                            AssetFactory.create(isCamera: false, fromFileUrl: url,
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
                                #if DEBUG
                                debugPrint("[\(String(describing: type(of: self)))] asset=\(asset?.description ?? "(nil)")")
                                #endif
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


    // MARK: UICollectionViewDelegate override

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedRow = -1  // Reset project selection before super reloads the table
        super.collectionView(collectionView, didSelectItemAt: indexPath)
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

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }

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

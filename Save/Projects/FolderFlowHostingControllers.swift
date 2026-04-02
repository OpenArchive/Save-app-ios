//
//  FolderFlowHostingControllers.swift
//  Save
//
//  UIHostingController entry points for add-folder / browse (SwiftUI migration slice).
//

import SwiftUI
import UIKit

// MARK: - Weak reference helper

private final class WeakRef<T: AnyObject> {
    weak var value: T?
    init() {}
}

// MARK: - Browse folder add (duplicate check + alerts)

enum BrowseFolderAddAction {
    static func perform(folder: BrowseFolder, presenter: UIViewController) {
        guard let space = SelectedSpace.space else { return }

        let exists = DuplicateFolderAlert(nil).exists(spaceId: space.id, name: folder.name)

        if exists {
            HostedCustomAlertPresenter.present(
                from: presenter,
                model: CustomAlertPresentationModel(
                    title: NSLocalizedString("Error", comment: ""),
                    message: NSLocalizedString("Please choose another name/folder or use the existing one instead.", comment: ""),
                    primaryButtonTitle: NSLocalizedString("Ok", comment: ""),
                    primaryButtonAction: {},
                    showCheckbox: false,
                    iconImage: Image("ic_error"),
                    iconTint: .gray
                )
            )
        } else {
            let project = Project(name: folder.name, space: space)
            Db.writeConn?.setObject(project)
            SelectedProject.project = project
            SelectedProject.store()

            HostedCustomAlertPresenter.present(
                from: presenter,
                model: CustomAlertPresentationModel(
                    title: NSLocalizedString("Success!", comment: ""),
                    message: NSLocalizedString("You have added a folder successfully.", comment: ""),
                    primaryButtonTitle: NSLocalizedString("Got it", comment: ""),
                    primaryButtonAction: {
                        AppNavigationRouter.shared.popToMainViewController(animated: true)
                    },
                    showCheckbox: false,
                    iconImage: Image("check_icon")
                )
            )
        }
    }
}

// MARK: - Add folder (choose create vs browse)

final class AddFolderNavAdapter: ObservableObject {
    weak var host: UIViewController?

    func createNew() {
        host?.navigationController?.pushViewController(AddNewFolderHostingController(), animated: true)
    }

    func browse() {
        let useTorSession = SelectedSpace.space is WebDavSpace
        host?.navigationController?.pushViewController(BrowseHostingController(useTorSession: useTorSession), animated: true)
    }
}

struct AddFolderRootView: View {
    @ObservedObject var adapter: AddFolderNavAdapter

    var body: some View {
        AddFolderView(
            onCreateNew: { adapter.createNew() },
            onBrowse: { adapter.browse() }
        )
    }
}

final class AddFolderHostingController: UIHostingController<AddFolderRootView> {
    init() {
        let adapter = AddFolderNavAdapter()
        super.init(rootView: AddFolderRootView(adapter: adapter))
        adapter.host = self
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if SelectedSpace.space is IaSpace, var stack = navigationController?.viewControllers {
            stack.removeAll { $0 is AddFolderHostingController }
            stack.append(AddNewFolderHostingController())
            navigationController?.setViewControllers(stack, animated: false)
            return
        }
        title = NSLocalizedString("Add a Folder", comment: "")
        save_configureTealStackNavigationItem()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("AddFolder")
    }
}

// MARK: - Add folder (create new / IA-only path)

final class AddNewFolderHostingController: UIHostingController<CreateFolderView> {

    init() {
        let box = WeakRef<AddNewFolderHostingController>()
        let root = CreateFolderView(
            disableBackAction: { isDisabled in
                box.value?.navigationItem.hidesBackButton = isDisabled
            },
            dismissAction: {
                AppNavigationRouter.shared.popToMainViewController(animated: true)
            }
        )
        super.init(rootView: root)
        box.value = self
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        save_configureTealStackNavigationItem()
        if #available(iOS 14.0, *) {
            navigationItem.title = NSLocalizedString("Create a New Folder", comment: "")
        }
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("AddNewFolder")
    }
}

// MARK: - Browse existing folders

final class BrowseHostingController: UIHostingController<BrowseView> {

    /// Selection for the UIKit chromeless **ADD** bar button (SwiftUI `.toolbar` applies glass circles on newer iOS).
    private var folderPendingAdd: BrowseFolder?

    init(useTorSession: Bool) {
        let box = WeakRef<BrowseHostingController>()
        super.init(
            rootView: BrowseView(
                useTorSession: useTorSession,
                onSelectionChange: { folder in
                    box.value?.syncAddBarButton(selectedFolder: folder)
                }
            )
        )
        box.value = self
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        save_configureTealStackNavigationItem()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("BrowseExisting")
    }

    private func syncAddBarButton(selectedFolder: BrowseFolder?) {
        folderPendingAdd = selectedFolder
        if selectedFolder != nil {
            navigationItem.rightBarButtonItem = SaveNavigationBarButtons.makeChromelessPrimaryActionBarButtonItem(
                title: NSLocalizedString("ADD", comment: ""),
                target: self,
                action: #selector(addBarButtonTapped),
                accessibilityIdentifier: "btBrowseAdd"
            )
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    @objc private func addBarButtonTapped() {
        guard let folder = folderPendingAdd else { return }
        BrowseFolderAddAction.perform(folder: folder, presenter: self)
    }
}

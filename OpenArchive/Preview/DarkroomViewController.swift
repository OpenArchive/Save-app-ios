//
//  DarkroomViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 A scene which shows preview images, metadata and a toolbar.

 The user can swipe left/right to switch images and delete the image using
 the toolbar item.

 It also has a full-screen mode, where all UI is hidden.

 Nice animations, also.
 */
class DarkroomViewController: BaseViewController, UIPageViewControllerDataSource,
UIPageViewControllerDelegate, InfoBoxDelegate {

    var selected = 0

    var addMode = false

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosHeight: NSLayoutConstraint?
    @IBOutlet weak var infosBottom: NSLayoutConstraint!

    @IBOutlet weak var toolbar: UIToolbar!
    private lazy var toolbarHeight: NSLayoutConstraint = toolbar.heightAnchor.constraint(equalToConstant: 0)

    private lazy var desc: InfoBox? = {
        let box = InfoBox.instantiate("ic_tag", infos)

        box?.delegate = self

        return box
    }()

    private lazy var location: InfoBox? = {
        let box = InfoBox.instantiate("ic_location", infos)

        box?.delegate = self

        return box
    }()

    private lazy var notes: InfoBox? = {
        let box = InfoBox.instantiate("ic_edit", infos)
        
        box?.delegate = self

        return box
    }()

    private lazy var flag: InfoBox? = {
        let box = InfoBox.instantiate("ic_flag", infos)

        box?.icon.tintColor = UIColor.warning
        box?.textView.isEditable = false
        box?.textView.isSelectable = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(flagged))
        tap.cancelsTouchesInView = true
        box?.addGestureRecognizer(tap)

        return box
    }()


    private let sc = SelectedCollection()

    private var asset: Asset? {
        return selected < 0 || selected >= sc.count
            ? nil
            : sc.getAsset(selected)
    }

    private var showUi = true

    private lazy var pageVc: UIPageViewController = {
        let pageVc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVc.dataSource = self
        pageVc.delegate = self

        return pageVc
    }()

    private let descPlaceholder = "Add People".localize()
    private let locPlaceholder = "Add Location".localize()
    private let notesPlaceholder = "Add Notes".localize()
    private let flagPlaceholder = "Tap to flag as significant content".localize()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = MultilineTitle()

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)
        pageVc.setViewControllers(getFreshImageVcList(), direction: .forward, animated: false)

        desc?.addConstraints(infos, bottom: location)
        location?.addConstraints(infos, top: desc, bottom: notes)
        notes?.addConstraints(infos, top: location, bottom: flag)
        flag?.addConstraints(infos, top: notes)

        infosHeight?.isActive = false

        toolbarHeight.isActive = false

        refresh()

        Db.add(observer: self, #selector(yapDatabaseModified))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: BaseViewController

    override func keyboardWillShow(notification: Notification) {
        if let kbSize = getKeyboardSize(notification) {
            infosBottom.constant = kbSize.height

            animateDuringKeyboardMovement(notification)
        }
    }

    override func keyboardWillBeHidden(notification: Notification) {
        infosBottom.constant = 0

        animateDuringKeyboardMovement(notification)
    }


    // MARK: UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {

        let index = (viewController as? ImageViewController)?.index ?? Int.min

        if index <= 0 {
            return nil
        }

        return getImageVc(index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {

        let index = (viewController as? ImageViewController)?.index ?? Int.max

        if index >= sc.count - 1 {
            return nil
        }

        return getImageVc(index + 1)
    }


    // MARK: UIPageViewControllerDelegate

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed,
            let index = (pageViewController.viewControllers?.first as? ImageViewController)?.index {

            if desc?.textView.isFirstResponder ?? false {
                asset?.desc = desc?.textView.text
                store()
            }
            else if location?.textView.isFirstResponder ?? false {
                asset?.location = desc?.textView.text
                store()
            }
            else if notes?.textView.isFirstResponder ?? false {
                asset?.notes = notes?.textView.text
                store()
            }

            selected = index

            refresh()
        }
    }


    // MARK: InfoBoxDelegate

    /**
     Callback for `desc`, `location` and `notes`.

     Store changes.
     */
    func textChanged(_ infoBox: InfoBox, _ text: String) {
        let asset = self.asset

        switch infoBox {
        case desc:
            asset?.desc = text

        case location:
            asset?.location = text

        default:
            asset?.notes = text
        }

        store()
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let (sectionChanges, rowChanges) = sc.yapDatabaseModified()

        if sectionChanges.count < 1 && rowChanges.count < 1 {
            return
        }

        for change in sectionChanges {
            switch change.type {
            case .delete:
                // If there's no assets left, leave immediately.
                navigationController?.popViewController(animated: true)
                return

            default:
                break
            }
        }

        for change in rowChanges {
            switch change.type {
            case .delete:
                if change.indexPath?.row == selected {
                    var direction = UIPageViewController.NavigationDirection.forward

                    if selected >= sc.count {
                        selected = sc.count - 1
                        direction = .reverse
                    }

                    DispatchQueue.main.async {
                        self.pageVc.setViewControllers(self.getFreshImageVcList(),
                                                       direction: direction, animated: true)

                        self.refresh()
                    }
                }

            case .insert:
                if change.newIndexPath?.row == selected {
                    DispatchQueue.main.async {
                        self.pageVc.setViewControllers(self.getFreshImageVcList(),
                                                       direction: .forward, animated: false)

                        self.refresh()
                    }
                }

            default:
                break
            }
        }
    }


    // MARK: Actions

    @IBAction func remove() {
        guard let asset = asset else {
            return
        }

        present(RemoveAssetAlert([asset]), animated: true)
    }

    @IBAction func toggleUi() {
        if addMode {
            dismissKeyboard()  // Also stores newly entered texts.

            return
        }

        showUi = !showUi

        navigationController?.setNavigationBarHidden(!showUi, animated: true)

        // This should not be nil, but it is sometimes, for an unkown reason.
        if infosHeight == nil {
            infosHeight = infos.heightAnchor.constraint(equalToConstant: 0)
        }

        infosHeight?.isActive = !showUi
        toolbarHeight.isActive = !showUi

        if showUi {
            self.infos.isHidden = false
            self.toolbar.isHidden = false
        }

        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
            }) { _ in
                if !self.showUi {
                    self.infos.isHidden = true
                    self.toolbar.isHidden = true
                }
        }
    }

    @IBAction func addInfo(_ sender: UIBarButtonItem) {
        addMode = !addMode

        sender.title = addMode ? "Done".localize() : "Add Info".localize()

        if !addMode {
            dismissKeyboard() // Also stores newly entered texts.

            self.toolbar.isHidden = false
        }

        setInfos(defaults: addMode)

        toolbarHeight.isActive = addMode

        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        }) { _ in
            if self.addMode {
                self.toolbar.isHidden = true
            }
        }
    }

    @objc func flagged() {
        if addMode {
            asset?.flagged = !(asset?.flagged ?? false)

            setInfos(defaults: addMode)

            store()
        }
    }


    // MARK: Private Methods

    private func refresh() {
        let asset = self.asset // Don't repeat asset#get all the time.

        let title = navigationItem.titleView as? MultilineTitle
        title?.title.text = asset?.filename
        title?.subtitle.text = Formatters.formatByteCount(asset?.filesize)

        setInfos(defaults: addMode)

        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }

    private func getImageVc(_ index: Int) -> ImageViewController? {
        let vc = ImageViewController.initFromStoryboard()

        vc?.image = sc.getAsset(index)?.getThumbnail()
        vc?.index = index

        return vc
    }

    private func getFreshImageVcList() -> [ImageViewController] {
        var vcs = [ImageViewController]()

        if let vc = getImageVc(selected) {
            vcs.append(vc)
        }

        return vcs
    }

    private func setInfos(defaults: Bool = false) {
        desc?.set(asset?.desc, with: defaults ? descPlaceholder : nil)
        desc?.textView.isEditable = addMode

        location?.set(asset?.location, with: defaults ? locPlaceholder : nil)
        location?.textView.isEditable = addMode

        notes?.set(asset?.notes, with: defaults ? notesPlaceholder : nil)
        notes?.textView.isEditable = addMode

        flag?.set(asset?.flagged ?? false ? Asset.flag : nil,
                  with: defaults ? flagPlaceholder : nil)
    }

    private func store() {
        guard let asset = asset else {
            return
        }

        Db.writeConn?.asyncReadWrite { transaction in
            transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
        }
    }
}

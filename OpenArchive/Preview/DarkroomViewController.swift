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

    enum DirectEdit {
        case description
        case location
        case notes
    }

    var selected = 0

    var directEdit: DarkroomViewController.DirectEdit?

    var addMode = false

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosHeight: NSLayoutConstraint?
    @IBOutlet weak var infosBottom: NSLayoutConstraint!

    @IBOutlet weak var toolbar: UIToolbar!
    private lazy var toolbarHeight: NSLayoutConstraint = toolbar.heightAnchor.constraint(equalToConstant: 0)


    private let sc = SelectedCollection()
    private var dh: DarkroomHelper?

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

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = MultilineTitle()

        if !addMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Add Info".localize(), style: .plain, target: self, action: #selector(addInfo))
        }

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)

        dh = DarkroomHelper(self, infos)

        infosHeight?.isActive = false

        toolbarHeight.isActive = addMode

        Db.add(observer: self, #selector(yapDatabaseModified))

        refresh(animate: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        BatchInfoAlert.presentIfNeeded(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if directEdit == .description {
            dh?.desc?.textView.becomeFirstResponder()
        }
        else if directEdit == .location {
            dh?.location?.textView.becomeFirstResponder()
        }
        else if directEdit == .notes {
            dh?.notes?.textView.becomeFirstResponder()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return  .lightContent
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

            if dh?.desc?.textView.isFirstResponder ?? false {
                asset?.desc = dh?.desc?.textView.text
                store()
            }
            else if dh?.location?.textView.isFirstResponder ?? false {
                asset?.location = dh?.location?.textView.text
                store()
            }
            else if dh?.notes?.textView.isFirstResponder ?? false {
                asset?.notes = dh?.notes?.textView.text
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
        case dh?.desc:
            asset?.desc = text

        case dh?.location:
            asset?.location = text

        default:
            asset?.notes = text
        }

        store()
    }

    func tapped(_ infoBox: InfoBox) {
        if addMode {
            asset?.flagged = !(asset?.flagged ?? false)

            dh?.setInfos(asset, defaults: addMode, isEditable: addMode)

            store()

            FlagInfoAlert.presentIfNeeded()
        }
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
                        self.refresh(direction: direction)
                    }
                }

            case .insert:
                if change.newIndexPath?.row == selected {
                    DispatchQueue.main.async {
                        self.refresh(direction: .forward)
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

    @IBAction func addInfo() {
        addMode = !addMode

        navigationItem.rightBarButtonItem?.title = addMode ? "Done".localize() : "Add Info".localize()

        if !addMode {
            dismissKeyboard() // Also stores newly entered texts.

            self.toolbar.isHidden = false
        }

        toolbarHeight.isActive = addMode

        refresh()
    }


    // MARK: Private Methods

    private func refresh(animate: Bool = true, direction: UIPageViewController.NavigationDirection? = nil) {
        let asset = self.asset // Don't repeat asset#get all the time.

        let title = navigationItem.titleView as? MultilineTitle
        title?.title.text = addMode ? "Add Info".localize() : asset?.filename
        title?.subtitle.text = addMode ? asset?.filename : Formatters.formatByteCount(asset?.filesize)

        navigationItem.rightBarButtonItem?.isEnabled = asset != nil && !asset!.isUploaded && !asset!.isUploading

        if pageVc.viewControllers?.isEmpty ?? true || direction != nil {
            pageVc.setViewControllers(getFreshImageVcList(), direction: direction ?? .forward, animated: direction != nil)
        }

        dh?.setInfos(asset, defaults: addMode, isEditable: addMode)

        if animate {
            UIView.animate(withDuration: 0.5, animations: {
                self.view.layoutIfNeeded()
            }) { _ in
                self.toolbar.isHidden = self.addMode
            }
        }
        else {
            toolbar.isHidden = addMode
        }
    }

    private func getImageVc(_ index: Int) -> ImageViewController {
        let vc = UIStoryboard.main.instantiate(ImageViewController.self)

        vc.image = sc.getAsset(index)?.getThumbnail()
        vc.index = index

        return vc
    }

    private func getFreshImageVcList() -> [ImageViewController] {
        return [getImageVc(selected)]
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

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

    private static let descPlaceholder = "Add People".localize()
    private static let locPlaceholder = "Add Location".localize()
    private static let notesPlaceholder = "Add Notes".localize()
    private static let flagPlaceholder = "Tap to flag as significant content".localize()

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

        desc?.addConstraints(infos, bottom: location)
        location?.addConstraints(infos, top: desc, bottom: notes)
        notes?.addConstraints(infos, top: location, bottom: flag)
        flag?.addConstraints(infos, top: notes)

        infosHeight?.isActive = false

        toolbarHeight.isActive = addMode

        Db.add(observer: self, #selector(yapDatabaseModified))

        refresh()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if directEdit == .description {
            desc?.textView.becomeFirstResponder()
        }
        else if directEdit == .location {
            location?.textView.becomeFirstResponder()
        }
        else if directEdit == .notes {
            notes?.textView.becomeFirstResponder()
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
                        self.refresh(direction)
                    }
                }

            case .insert:
                if change.newIndexPath?.row == selected {
                    DispatchQueue.main.async {
                        self.refresh(.forward)
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

    @objc func flagged() {
        if addMode {
            asset?.flagged = !(asset?.flagged ?? false)

            setInfos(defaults: addMode)

            store()

            FlagInfoAlert.presentIfNeeded()
        }
    }


    // MARK: Private Methods

    private func refresh(_ direction: UIPageViewController.NavigationDirection? = nil) {
        let asset = self.asset // Don't repeat asset#get all the time.

        let title = navigationItem.titleView as? MultilineTitle
        title?.title.text = addMode ? "Add Info".localize() : asset?.filename
        title?.subtitle.text = addMode ? asset?.filename : Formatters.formatByteCount(asset?.filesize)

        navigationItem.rightBarButtonItem?.isEnabled = !(asset?.isUploaded ?? true)

        if pageVc.viewControllers?.isEmpty ?? true || direction != nil {
            pageVc.setViewControllers(getFreshImageVcList(), direction: direction ?? .forward, animated: direction != nil)
        }

        setInfos(defaults: addMode)

        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        }) { _ in
            if self.addMode {
                self.toolbar.isHidden = true
            }
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

    private func setInfos(defaults: Bool = false) {
        desc?.set(asset?.desc, with: defaults ? DarkroomViewController.descPlaceholder : nil)
        desc?.textView.isEditable = addMode

        location?.set(asset?.location, with: defaults ? DarkroomViewController.locPlaceholder : nil)
        location?.textView.isEditable = addMode

        notes?.set(asset?.notes, with: defaults ? DarkroomViewController.notesPlaceholder : nil)
        notes?.textView.isEditable = addMode

        flag?.set(asset?.flagged ?? false ? Asset.flag : nil,
                  with: defaults ? DarkroomViewController.flagPlaceholder : nil)
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

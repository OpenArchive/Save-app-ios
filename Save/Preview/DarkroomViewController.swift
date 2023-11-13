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

    @IBOutlet weak var container: UIView!

    @IBOutlet weak var counterLb: UILabel!
    @IBOutlet weak var flagBt: UIButton! {
        didSet {
            flagBt.setTitle("")
            flagBt.setImage(.init(systemName: "flag.fill"), for: .selected)
        }
    }
    @IBOutlet weak var backwardBt: UIButton! {
        didSet {
            backwardBt.setTitle("")
        }
    }
    @IBOutlet weak var forwardBt: UIButton! {
        didSet {
            forwardBt.setTitle("")
        }
    }

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosHeight: NSLayoutConstraint?
    @IBOutlet weak var infosBottom: NSLayoutConstraint?


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

        addChild(pageVc)
        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        pageVc.didMove(toParent: self)

        // Use the new keyboard layout guide, if available, that's more reliable
        // than any calculation.
        if #available(iOS 15.0, *) {
            infosBottom?.isActive = false
            infos.bottomAnchor.constraint(equalTo: infos.keyboardLayoutGuide.topAnchor).isActive = true
        }

        // Deactivate before initializing DarkroomHelper, because otherwise
        // the constraints debugger spams the debug log.
        infosHeight?.isActive = false

        dh = DarkroomHelper(self, infos)

        Db.add(observer: self, #selector(yapDatabaseModified))

        refresh(animate: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)

        BatchInfoAlert.presentIfNeeded(self, additionalCondition: sc.count > 1)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return  .lightContent
    }


    // MARK: BaseViewController

    override func keyboardWillShow(notification: Notification) {
        if let infosBottom = infosBottom,
            let kbSize = getKeyboardSize(notification)
        {
            infosBottom.constant = view.bounds.maxY - kbSize.minY
        }

        animateDuringKeyboardMovement(notification)
    }

    override func keyboardWillBeHidden(notification: Notification) {
        infosBottom?.constant = 0

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
                            transitionCompleted completed: Bool) 
    {
        if completed,
           let index = (pageViewController.viewControllers?.first as? ImageViewController)?.index
        {
            if let update = dh?.assign(dh?.getFirstResponder()) {
                asset?.update(update)
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
        if let update = dh?.assign((infoBox, text)) {
            asset?.update(update)
        }
    }

    func tapped(_ infoBox: InfoBox) {
        toggleFlagged()
    }


    // MARK: Observers

    /**
     Callback for `YapDatabaseModified` and `YapDatabaseModifiedExternally` notifications.

     Will be called, when something changed the database.
     */
    @objc func yapDatabaseModified(notification: Notification) {
        let (forceFull, sectionChanges, rowChanges) = sc.yapDatabaseModified()

        if forceFull {
            DispatchQueue.main.async {
                self.refresh()
            }

            return
        }

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
        dismissKeyboard()  // Also stores newly entered texts.
    }

    @IBAction func toggleFlagged() {
        let update = dh?.assign(dh?.getFirstResponder())

        asset?.update({ asset in
            asset.flagged = !asset.flagged

            update?(asset)
        })

        dh?.setInfos(asset, defaults: true)

        FlagInfoAlert.presentIfNeeded()
    }

    @IBAction func backward() {
        selected = max(0, selected - 1)

        refresh(direction: .reverse)
    }

    @IBAction func forward() {
        selected = min(selected + 1, sc.count - 1)

        refresh(direction: .forward)
    }


    // MARK: Private Methods

    private func refresh(animate: Bool = true, direction: UIPageViewController.NavigationDirection? = nil) {
        let asset = self.asset // Don't repeat asset#get all the time.

        let title = navigationItem.titleView as? MultilineTitle
        title?.title.text = NSLocalizedString("Add Info", comment: "")
        title?.subtitle.text = asset?.filename

        navigationItem.rightBarButtonItem?.isEnabled = asset != nil && !asset!.isUploaded && !asset!.isUploading

        counterLb.text = String(format: NSLocalizedString("%1$@/%2$@", comment: "both are integer numbers meaning 'x of n'"),
                                Formatters.format(selected + 1), Formatters.format(sc.count))
        flagBt.isSelected = asset?.flagged ?? false

        backwardBt.toggle(selected > 0, animated: animate)
        forwardBt.toggle(selected < sc.count - 1, animated: animate)

        if pageVc.viewControllers?.isEmpty ?? true || direction != nil {
            pageVc.setViewControllers(getFreshImageVcList(), direction: direction ?? .forward, animated: direction != nil)
        }

        dh?.setInfos(asset, defaults: true)
    }

    private func getImageVc(_ index: Int) -> ImageViewController {
        let vc = UIStoryboard.main.instantiate(ImageViewController.self)
        let asset = sc.getAsset(index)

        vc.image = asset?.getThumbnail()
        vc.index = index
        vc.isAv = asset?.isAv
        vc.duration = asset?.duration

        return vc
    }

    private func getFreshImageVcList() -> [ImageViewController] {
        return [getImageVc(selected)]
    }
}

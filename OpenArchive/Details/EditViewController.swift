//
//  EditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

/**
 TODO: This needs scrolling/moving of form fields on iPhone 5!
 */
class EditViewController: BaseViewController, UITextViewDelegate,
    UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    class func initFromStoryboard() -> EditViewController? {
        return UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "editViewController") as? EditViewController
    }

    enum DirectEdit {
        case description
        case location
    }

    @IBOutlet weak var closeBt: UIButton!
    @IBOutlet weak var tagBt: UIButton!
    @IBOutlet weak var locationBt: UIButton!
    @IBOutlet weak var flagBt: UIButton!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var descTv: UITextView!
    @IBOutlet weak var locationTv: UITextView!

    var collection: Collection?

    var selected: Int?

    var directEdit: EditViewController.DirectEdit?

    private var asset: Asset? {
        return selected ?? Int.min < 0 || selected ?? Int.max >= (collection?.assets.count ?? 0)
            ? nil
            : collection?.assets[selected!]
    }

    private var descPlaceholder = "Who or what can be seen here?".localize()
    private var locPlaceholder = "No location".localize()

    private var originalFrame: CGRect?


    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardOnOutsideTap()

        let pageVc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVc.dataSource = self
        pageVc.delegate = self

        addChild(pageVc)

        container.addSubview(pageVc.view)
        pageVc.view.frame = container.bounds
        
        pageVc.didMove(toParent: self)

        var vcs = [ImageViewController]()

        if let vc = getImageVc(selected ?? 0) {
            vcs.append(vc)
        }

        pageVc.setViewControllers(vcs, direction: .forward, animated: false)

        refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if directEdit == .description {
            descTv.becomeFirstResponder()
        }
        else if directEdit == .location {
            locationTv.becomeFirstResponder()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return  .lightContent
    }

    /**
     Callback for `UIResponder.keyboardWillShowNotification`.

     - parameter notification: The calling notification.
     */
    @objc open override func keyboardWillShow(notification: Notification) {
        if let kbSize = getKeyboardSize(notification) {

            if originalFrame == nil {
                originalFrame = view.frame
            }

            let f = originalFrame!

            view.frame = CGRect(x: f.minX, y: f.minY, width: f.width,
                                height: f.height - kbSize.height)

            animateDuringKeyboardMovement(notification)
        }
    }

    /**
     Callback for `UIResponder.keyboardWillHideNotification`.

     - parameter notification: A `keyboardWillHideNotification`. Ignored.
     */
    @objc open override func keyboardWillBeHidden(notification: Notification) {
        if let originalFrame = originalFrame {
            view.frame = originalFrame
        }

        animateDuringKeyboardMovement(notification)
    }


    // MARK: UITextViewDelegate

    /**
     Callback for `descTv` and `locationBt`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, manually remove placeholder, if any.
     */
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if textView == descTv {
            if textView.text == descPlaceholder {
                textView.text = nil
            }
        }
        else {
            if textView.text == locPlaceholder {
                textView.text = nil
            }
        }

        return true
    }

    /**
     Callback for `descTv` and `locationBt`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, restore placeholder, if nothing entered.

     Update indicator button and store changes.
     */
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == descTv {
            asset?.desc = textView.text

            if textView.text.isEmpty {
                textView.text = descPlaceholder
            }

            tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)
        }
        else {
            asset?.location = textView.text

            if textView.text.isEmpty {
                textView.text = locPlaceholder
            }

            locationBt.isSelected = !(asset?.location?.isEmpty ?? true)
        }

        store()
    }

    /**
     Callback for `descTv` and `locationBt`.

     Go to next field, if user hits [enter].
     Hide keyboard, when user hits [enter].
     */
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            if textView == descTv {
                locationTv.becomeFirstResponder()
            }
            else {
                dismissKeyboard()
            }

            return false
        }

        return true
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

        if index >= (collection?.assets.count ?? 0) - 1 {
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

            selected = index

            refresh()
        }
    }


    // MARK: Actions

    @IBAction func flag() {
        asset?.flagged = !(asset?.flagged ?? true)
        flagBt.isSelected = asset?.flagged ?? false

        store()
    }


    // MARK: Private Methods

    private func refresh() {
        let asset = self.asset // Don't repeat asset#get all the time.

        let allowEdit = !(asset?.isUploaded ?? true)

        if !allowEdit {
            dismissKeyboard()
        }

        tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)

        locationBt.isSelected = !(asset?.location?.isEmpty ?? true)

        flagBt.isUserInteractionEnabled = allowEdit
        flagBt.isSelected = asset?.flagged ?? false

        descTv.isSelectable = allowEdit
        descTv.isEditable = allowEdit
        descTv.text = !descTv.isFirstResponder && (asset?.desc?.isEmpty ?? true)
            ? descPlaceholder : asset?.desc

        locationTv.isSelectable = allowEdit
        locationTv.isEditable = allowEdit
        locationTv.text = !locationTv.isFirstResponder && (asset?.location?.isEmpty ?? true)
            ? locPlaceholder : asset?.location
    }

    private func store() {
        if let asset = asset {
            Db.writeConn?.asyncReadWrite { transaction in
                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }
        }
    }

    private func getImageVc(_ index: Int) -> ImageViewController? {
        let vc = ImageViewController.initFromStoryboard()

        vc?.image = collection?.assets[index].getThumbnail()
        vc?.index = index

        return vc
    }
}

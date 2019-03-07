//
//  EditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 07.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit

class EditViewController: BaseViewController, UITextViewDelegate, UITextFieldDelegate,
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
    @IBOutlet weak var locationTf: UITextField!

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
            locationTf.becomeFirstResponder()
        }
    }


    // MARK: UITextViewDelegate

    /**
     Callback for `descTv`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, manually remove placeholder, if any.
     */
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        if textView.text == descPlaceholder {
            textView.text = nil
        }

        return true
    }

    /**
     Callback for `descTv`.

     `UITextViews` cannot have placeholders like `UITextField`.
     Therefore, restore placeholder, if nothing entered.

     Update indicator button and store changes.
     */
    func textViewDidEndEditing(_ textView: UITextView) {
        asset?.desc = textView.text

        if textView.text.isEmpty {
            textView.text = descPlaceholder
        }

        tagBt.isSelected = !(asset?.desc?.isEmpty ?? true)

        store()
    }

    /**
     Callback for `descTv`.

     Go to next field, if user hits [enter].
     */
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            locationTf.becomeFirstResponder()

            return false
        }

        return true
    }


    // MARK: UITextFieldDelegate

    /**
     Callback for `locationBt`.

     Hide keyboard, when user hits [enter].
    */
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()

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

    /**
     Callback for `locationBt`.

     `UITextField` placeholders are dark grey. Not great on almost black background.
     Therefore, manually remove placeholder, if any.
     */
    @IBAction func locationEditingDidBegin() {
        if locationTf.text == locPlaceholder {
            locationTf.text = nil
        }
    }
    
    /**
     Callback for `locationBt`.

     `UITextField` placeholders are dark grey. Not great on almost black background.
     Therefore, restore placeholder, if nothing entered.

     Update indicator button and store changes.
     */
    @IBAction func locationEditingDidEnd() {
        asset?.location = locationTf.text

        if locationTf.text?.isEmpty ?? true {
            locationTf.text = locPlaceholder
        }

        locationBt.isSelected = !(asset?.location?.isEmpty ?? true)

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

        locationTf.isEnabled = allowEdit
        locationTf.text = !locationTf.isEditing && (asset?.location?.isEmpty ?? true)
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

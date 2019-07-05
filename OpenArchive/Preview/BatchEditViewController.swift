//
//  BatchEditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import AlignedCollectionViewFlowLayout

class BatchEditViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, InfoBoxDelegate {

    var assets: [Asset]?

    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var infos: UIView!
    @IBOutlet weak var infosHeight: NSLayoutConstraint?
    @IBOutlet weak var infosBottom: NSLayoutConstraint!

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


    override func viewDidLoad() {
        super.viewDidLoad()

        let title = MultilineTitle()
        title.title.text = "Batch Edit".localize()
        title.subtitle.text = "% Items Selected".localize(value: Formatters.format(assets?.count))
        navigationItem.titleView = title

        let alignedFlowLayout = collectionView?.collectionViewLayout as? AlignedCollectionViewFlowLayout
        alignedFlowLayout?.horizontalAlignment = .left
        alignedFlowLayout?.verticalAlignment = .top

        desc?.addConstraints(infos, bottom: location)
        location?.addConstraints(infos, top: desc, bottom: notes)
        notes?.addConstraints(infos, top: location, bottom: flag)
        flag?.addConstraints(infos, top: notes)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return false
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseId, for: indexPath) as! ImageCell

        cell.highlightNonUploaded = false
        cell.asset = assets?[indexPath.row]

        return cell
    }


    // MARK: InfoBoxDelegate

    /**
     Callback for `desc`, `location` and `notes`.

     Store changes.
     */
    func textChanged(_ infoBox: InfoBox, _ text: String) {
        switch infoBox {
        case desc:
            for asset in assets ?? [] {
                asset.desc = text
            }

        case location:
            for asset in assets ?? [] {
                asset.location = text
            }

        default:
            for asset in assets ?? [] {
                asset.notes = text
            }
        }

        store()
    }


    // MARK: Actions

    @objc func flagged() {
        // Take the first's status and set all of them to that.
        let flagged = !(assets?.first?.flagged ?? false)


        for asset in assets ?? [] {
            asset.flagged = flagged
        }

        store()

        FlagInfoAlert.presentIfNeeded()
    }


    // MARK: Private Methods

    private func store() {
        guard let assets = assets else {
            return
        }

        Db.writeConn?.asyncReadWrite { transaction in
            for asset in assets {
                transaction.setObject(asset, forKey: asset.id, inCollection: Asset.collection)
            }
        }
    }
}

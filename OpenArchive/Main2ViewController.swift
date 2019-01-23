//
//  Main2ViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 23.01.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import MaterialComponents.MaterialTabs

class Main2ViewController: UIViewController, UICollectionViewDelegate,
UICollectionViewDataSource, MDCTabBarDelegate {

    @IBOutlet weak var tabBarContainer: UIView!

    private lazy var tabBar: MDCTabBar = {
        let tabBar = MDCTabBar(frame: tabBarContainer.bounds)
        tabBar.items = [
            UITabBarItem(title: "All".localize(), image: nil, tag: 1),
            UITabBarItem(title: "+".localize(), image: nil, tag: 2),
        ]
        tabBar.delegate = self

        tabBar.itemAppearance = .titles

        tabBar.setTitleColor(view.tintColor, for: .normal)
        tabBar.setTitleColor(UIColor.black, for: .selected)

        tabBar.bottomDividerColor = UIColor.lightGray

        tabBar.sizeToFit()

        return tabBar
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarContainer.addSubview(tabBar)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)
    }


    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
    }


    // MARK: Actions

    @IBAction func upload() {
    }
}

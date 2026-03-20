//
//  DarkroomViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 17.05.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class DarkroomViewController: UIViewController {

    var selected = 0
    
    // MARK: Storyboard outlet placeholders (removed, SwiftUI handles UI)
    @IBOutlet weak var container: UIView! {
        didSet { container?.removeFromSuperview() }
    }
    @IBOutlet weak var counterLb: UILabel! {
        didSet { counterLb?.removeFromSuperview() }
    }
    @IBOutlet weak var flagIv: Flag! {
        didSet { flagIv?.removeFromSuperview() }
    }
    @IBOutlet weak var backwardBt: UIButton! {
        didSet { backwardBt?.removeFromSuperview() }
    }
    @IBOutlet weak var forwardBt: UIButton! {
        didSet { forwardBt?.removeFromSuperview() }
    }
    @IBOutlet weak var infoView: UIView! {
        didSet { infoView?.removeFromSuperview() }
    }
    @IBOutlet weak var infoViewBottomConstraint: NSLayoutConstraint?
    
    private let sc = SelectedCollection()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        navigationItem.title = NSLocalizedString("Edit Media Info", comment: "")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "DONE",
            style: .done,
            target: self,
            action: #selector(dismissView)
        )
        
        setupSwiftUIView()
    }
    
    private func setupSwiftUIView() {
        let darkroomView = DarkroomView(
            initialIndex: selected,
            onDismiss: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onRemoveAsset: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        
        let hostingController = UIHostingController(rootView: darkroomView)
        hostingController.view.backgroundColor = .black
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        BatchInfoAlert.presentIfNeeded(viewController: self, additionalCondition: sc.count > 1)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @objc private func dismissView() {
        navigationController?.popViewController(animated: true)
    }
}

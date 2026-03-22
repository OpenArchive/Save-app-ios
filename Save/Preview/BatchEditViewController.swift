//
//  BatchEditViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 05.07.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class BatchEditViewController: UIViewController {
    
    var assets: [Asset]?
    
    // MARK: Storyboard outlet placeholders (removed, SwiftUI handles UI)
    @IBOutlet weak var image1: UIImageView! {
        didSet { image1?.removeFromSuperview() }
    }
    @IBOutlet weak var image2: UIImageView! {
        didSet { image2?.removeFromSuperview() }
    }
    @IBOutlet weak var image3: UIImageView! {
        didSet { image3?.removeFromSuperview() }
    }
    @IBOutlet weak var counterLb: UILabel! {
        didSet { counterLb?.removeFromSuperview() }
    }
    @IBOutlet weak var flagIv: Flag! {
        didSet { flagIv?.removeFromSuperview() }
    }
    @IBOutlet weak var infos: UIView! {
        didSet { infos?.removeFromSuperview() }
    }
    @IBOutlet weak var infosBottom: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        title = NSLocalizedString("Bulk Edit Media Info", comment: "")
        navigationItem.title = title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "DONE",
            style: .done,
            target: self,
            action: #selector(dismissView)
        )
        
        let batchEditView = BatchEditView(
            assets: assets ?? [],
            onDismiss: { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        
        let hostingController = UIHostingController(rootView: batchEditView)
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenViewSafely("BatchEdit")
    }
    
    @objc private func dismissView() {
        navigationController?.popViewController(animated: true)
    }
}

extension Notification {
    func keyboardHeight() -> CGFloat? {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue.height
    }
}

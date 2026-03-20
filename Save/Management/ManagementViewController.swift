//
//  ManagementViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.03.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import SwiftUI

class ManagementViewController: UIViewController {
    
    var delegate: DoneDelegate?
    
    private let titleView = MultilineTitle()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        titleView.title.text = NSLocalizedString("Edit Queue", comment: "")
        titleView.subtitle.text = NSLocalizedString("Uploading is paused", comment: "")
        titleView.title.font = .montserrat(forTextStyle: .callout, with: .traitUIOptimized)
        titleView.subtitle.font = .montserrat(forTextStyle: .caption1)
        titleView.title.textColor = .label
        titleView.subtitle.textColor = .gray70
        navigationItem.titleView = titleView
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = nil
        }
        
        let doneItem = UIBarButtonItem(
            title: NSLocalizedString("DONE", comment: ""),
            style: .plain,
            target: self,
            action: #selector(done)
        )
        if #available(iOS 26.0, *) {
            doneItem.hidesSharedBackground = true
        }
        navigationItem.rightBarButtonItem = doneItem

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        if let navBar = navigationController?.navigationBar {
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.compactAppearance = appearance
            navBar.isTranslucent = false
            navBar.tintColor = .label
        }
        
        let managementView = ManagementView(
            onDone: { [weak self] in self?.delegate?.done() },
            onTitleChange: { [weak self] title, subtitle in
                self?.titleView.title.text = title
                self?.titleView.subtitle.text = subtitle
            }
        )
        
        let hostingController = UIHostingController(rootView: managementView)
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
        // Edit Queue has no teal nav bar: use label color (black/white) and no bubble
        navigationController?.navigationBar.tintColor = .label
    }
    
    @IBAction func done() {
        NotificationCenter.default.post(name: .uploadManagerUnpause, object: nil)
        dismiss(animated: true)
    }
}

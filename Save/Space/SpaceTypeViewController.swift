//
//  SpaceTypeViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class SpaceTypeViewController: UIViewController, WizardDelegatable {
    
    weak var delegate: WizardDelegate?
    
    @IBOutlet weak var container: UIView!
    
    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString(
                "To get started, connect to a server to store your media.",
                comment: "")
        }
    }
    
    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = NSLocalizedString(
                "You can add another server to connect to multiple servers at any time",
                comment: "")
        }
    }
    private lazy var privateServerView: UIView = {
        let view = createOptionView(title: WebDavSpace.defaultPrettyName, icon:  UIImage(systemName: "server.rack"), action: #selector(newWebDav))
        return view
    }()
    
    private lazy var internetArchiveView: UIView = {
        let view = createOptionView(title: IaSpace.defaultPrettyName, icon :IaSpace.favIcon, action: #selector(newIa))
        return view
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        view.addSubview(privateServerView)
        
        NSLayoutConstraint.activate([
            privateServerView.topAnchor.constraint(equalTo: subtitleLb.bottomAnchor, constant: 32),
            privateServerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            privateServerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            privateServerView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        
        
        Db.bgRwConn?.read { tx in
            if tx.find(where: { (_: IaSpace) in true }) == nil {
                
                view.addSubview(internetArchiveView)
                NSLayoutConstraint.activate([
                    internetArchiveView.topAnchor.constraint(equalTo: privateServerView.bottomAnchor, constant: 16),
                    internetArchiveView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    internetArchiveView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
                    internetArchiveView.heightAnchor.constraint(equalTo: privateServerView.heightAnchor)
                ])
                
                
            }}
        let backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backBarButtonItem
        navigationItem.title = NSLocalizedString("Select a Server", comment: "")
        
    }
    
    
    // MARK: Actions
    
    @objc private  func newWebDav() {
        navigationController?.pushViewController(UIStoryboard.main.instantiate(WebDavWizardViewController.self),animated: true )
    }
    
    @objc private func  newIa() {
        navigationController?.pushViewController(InternetArchiveLoginViewController(), animated: true)
    }
    
    @IBAction func newGdrive() {
        //   delegate?.next(UIStoryboard.main.instantiate(GdriveWizardViewController.self), pos: 1)
    }
    
    private func createOptionView(title: String, icon: UIImage?, action: Selector) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let icon = UIImageView(image: icon)
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .systemGray
        arrow.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton()
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(icon)
        container.addSubview(label)
        container.addSubview(arrow)
        container.addSubview(button)
        
        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            
            arrow.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
}

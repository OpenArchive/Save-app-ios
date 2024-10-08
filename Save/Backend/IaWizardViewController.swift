//
//  IaWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 21.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit

class IaWizardViewController: BaseViewController, WizardDelegatable, ScrapeDelegate {
    
    weak var delegate: WizardDelegate?
    
    @IBOutlet weak var iconIv: UIImageView! {
        didSet {
            iconIv.image = .internetArchiveLogo
                .resizeFit(to: .icon)?
                .withRenderingMode(.alwaysTemplate)
        }
    }
    
    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = IaSpace.defaultPrettyName
        }
    }
    
    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = String(
                format: NSLocalizedString("internet_archive_description",
                                          comment: ""),
                Bundle.main.displayName, IaSpace.defaultPrettyName)
        }
    }
    
    @IBOutlet weak var accessKeyLb: UILabel! {
        didSet {
            accessKeyLb.text = NSLocalizedString("Username", comment: "")
        }
    }
    
    @IBOutlet weak var accessKeyTb: TextBox! {
        didSet {
            accessKeyTb.placeholder = NSLocalizedString("Username", comment: "")
            accessKeyTb.autocorrectionType = .no
            accessKeyTb.autocapitalizationType = .none
        }
    }
    
    @IBOutlet weak var secretKeyLb: UILabel! {
        didSet {
            secretKeyLb.text = NSLocalizedString("Password", comment: "")
        }
    }
    
    @IBOutlet weak var secretKeyTb: TextBox! {
        didSet {
            secretKeyTb.placeholder = NSLocalizedString("Password", comment: "")
            secretKeyTb.autocorrectionType = .no
            secretKeyTb.autocapitalizationType = .none
        }
    }
    
    //    @IBOutlet weak var acquireBt: UIButton! {
    //        didSet {
    //            acquireBt.setTitle(NSLocalizedString("Acquire Keys", comment: ""))
    //        }
    //    }
    //
    //    @IBOutlet weak var hintLb: UILabel! {
    //        didSet {
    //            let linkText = NSLocalizedString("learn how", comment: "")
    //
    //            let text = NSLocalizedString("If you do not have existing keys, %@ to acquire keys.", comment: "Placeholder is your translation of 'learn how'")
    //
    //            hintLb.attributedText = String(format: text, linkText)
    //                .attributed
    //                .link(part: linkText, into: hintLb)
    //        }
    //    }
    
    @IBOutlet weak var backBt: UIButton! {
        didSet {
            backBt.setTitle(NSLocalizedString("Back", comment: ""))
        }
    }
    
    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle(NSLocalizedString("Sign in", comment: ""))
        }
    }
    
    
    // MARK: Private Properties
    
    private lazy var scrapeNavC = UINavigationController()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    
    // MARK: ScrapeDelegate
    
    func scraped(accessKey: String, secretKey: String) {
        accessKeyTb.text = accessKey
        secretKeyTb.text = secretKey
        
        check()
        
        scrapeNavC.dismiss(animated: true)
    }
    
    
    // MARK: Actions
    
    @IBAction func acquireKeys() {
        let vc = IaScrapeViewController()
        vc.delegate = self
        
        scrapeNavC.viewControllers = [vc]
        
        present(scrapeNavC, animated: true)
    }
    
    @IBAction func back() {
        delegate?.back()
    }
    
    @IBAction func next() {
        guard check() else {
            return
        }
        
        let space = IaSpace(accessKey: accessKeyTb.text, secretKey: secretKeyTb.text)
        
        SelectedSpace.space = space
        
        Db.writeConn?.asyncReadWrite() { tx in
            SelectedSpace.store(tx)
            
            tx.setObject(space)
        }
        
        let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
        vc.spaceName = IaSpace.defaultPrettyName
        
        delegate?.next(vc, pos: 2)
    }
    
    
    // MARK: Private Methods
    
    @discardableResult
    private func check() -> Bool {
        accessKeyTb.status = accessKeyTb.text?.isEmpty ?? true ? .bad : .good
        secretKeyTb.status = secretKeyTb.text?.isEmpty ?? true ? .bad : .good
        
        return accessKeyTb.status == .good && secretKeyTb.status == .good
    }
}

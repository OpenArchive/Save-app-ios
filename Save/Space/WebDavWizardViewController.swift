//
//  WebDavWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import FavIcon

class WebDavWizardViewController: BaseViewController, WizardDelegatable, TextBoxDelegate {
    
    weak var delegate: WizardDelegate?
    
    @IBOutlet weak var iconIv: UIImageView!
    
    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString("Connect to a WebDAV-compatible servers, e.g. Nexcloud and ownCloud.", comment: "")
            titleLb.font = .montserrat(forTextStyle: .caption2 )
            titleLb.textColor = .gray70
        }
    }
    
    
    @IBOutlet weak var serverLb: UILabel! {
        didSet {
            serverLb.text = NSLocalizedString("Server info", comment: "")
            serverLb.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
            serverLb.textColor = .gray70
        }
    }
    
    @IBOutlet weak var urlTb: TextBox! {
        didSet {
            urlTb.placeholder = NSLocalizedString("Server URL", comment: "")
            urlTb.delegate = self
            urlTb.autocorrectionType = .no
            urlTb.autocapitalizationType = .none
            urlTb.textField.returnKeyType = .next
            urlTb.textField.font = .montserrat(forTextStyle: .footnote)
            urlTb.textField.textColor = .gray70
        }
    }
    
    
    @IBOutlet weak var accountLb: UILabel! {
        didSet {
            accountLb.text = NSLocalizedString("Account", comment: "")
            accountLb.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
            accountLb.textColor = .gray70
        }
    }
    
    @IBOutlet weak var usernameTb: TextBox! {
        didSet {
            usernameTb.placeholder = NSLocalizedString("Username", comment: "")
            usernameTb.delegate = self
            usernameTb.autocorrectionType = .no
            usernameTb.autocapitalizationType = .none
            usernameTb.textField.returnKeyType = .next
            usernameTb.textField.font = .montserrat(forTextStyle: .footnote)
            usernameTb.textField.textColor = .gray70
        }
    }
    
    @IBOutlet weak var passwordTb: TextBox! {
        didSet {
            passwordTb.placeholder = NSLocalizedString("Password", comment: "")
            passwordTb.delegate = self
            passwordTb.autocorrectionType = .no
            passwordTb.autocapitalizationType = .none
            passwordTb.status = .reveal
            passwordTb.textField.returnKeyType = .done
            passwordTb.textField.font = .montserrat(forTextStyle: .footnote)
            passwordTb.textField.textColor = .gray70
        }
    }
    
    
    @IBOutlet weak var backBt: UIButton! {
        didSet {
            backBt.setTitle(NSLocalizedString("Back", comment: ""))
            backBt.titleLabel?.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
            
        }
    }
    
    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle(NSLocalizedString("Next", comment: ""))
            nextBt.isEnabled = false
            nextBt.cornerRadius = 10
            nextBt.backgroundColor =  .gray50
            nextBt.titleLabel?.font = .montserrat(forTextStyle: .headline, with: .traitUIOptimized)
        }
    }
    
    private lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()
    
    private var url: URL? {
        Formatters.URLFormatter.fix(url: urlTb.text)
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        [urlTb, usernameTb, passwordTb].forEach { textField in
            textField?.textField.addTarget(self, action: #selector(updateButtonState), for: .editingChanged)
        }
        
        updateButtonState()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        self.title = NSLocalizedString("Private Server", comment: "")
    }
    
    
    @objc func updateButtonState() {
        nextBt.isEnabled = ![urlTb, usernameTb, passwordTb].contains { $0?.text?.isEmpty ?? true }
        nextBt.backgroundColor = nextBt.isEnabled ? .accent : .gray50
    }
    @objc override func dismissKeyboard() {
        view.endEditing(true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func back() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func next() {
        guard check() else {
            return
        }
        
        let space = WebDavSpace(
            name: "",
            url: url,
            favIcon: UIImage(named: "private_server"),
            username: usernameTb.text,
            password: passwordTb.text)
        
        workingOverlay.isHidden = false
        
        // Do a test request to check validity of space configuration.
        URLSession(configuration: UploadManager.improvedSessionConf()).info(space.url!, credential: space.credential) { [weak self] info, error in
            DispatchQueue.main.async {
                self?.workingOverlay.isHidden = true
                
                if let error = error {
                    if let self = self {
                        AlertHelper.present(self, message: error.friendlyMessage)
                        
                        self.usernameTb.status = .bad
                        self.passwordTb.status = .bad
                    }
                }
                else {
                    SelectedSpace.space = space
                    
                    Db.writeConn?.asyncReadWrite() { tx in
                        SelectedSpace.store(tx)
                        tx.setObject(space)
                    }
                    
                    let vc = UIStoryboard.main.instantiate(CreateCCLViewController.self)
                    vc.space = space
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
    
    override func keyboardWillShow(notification: Notification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        // Convert keyboard frame to scrollView's coordinate space
        let keyboardFrameInWindow = keyboardSize
        let scrollViewFrameInWindow = scrollView.convert(scrollView.bounds, to: nil)
        
        // Calculate the intersection of the keyboard and scrollView
        let intersection = scrollViewFrameInWindow.intersection(keyboardFrameInWindow)
        
        // If there's no intersection, we don't need any padding
        if intersection.isNull {
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
            return
        }
        
        // Only add the height of the overlapping area as bottom inset
        let contentInsets = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: intersection.height,
            right: 0.0
        )
        
        // Adjust scroll view content insets
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // If there's an active text field, scroll to make it visible
        if let activeField = view.findFirstResponder() as? UITextField {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            // Add some extra padding to ensure the text field isn't right at the keyboard
            let visibleRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y,
                width: rect.width,
                height: rect.height + 20 // Extra padding
            )
            scrollView.scrollRectToVisible(visibleRect, animated: true)
        }
    }
    
    // MARK: TextBoxDelegate
    
    func textBox(didUpdate textBox: TextBox) {
        urlTb.text = url?.absoluteString
        
    }
    
    func textBox(shouldReturn textBox: TextBox) -> Bool {
        switch textBox {
        case urlTb:
            usernameTb.becomeFirstResponder()
            
        case usernameTb:
            passwordTb.becomeFirstResponder()
            
        default:
            dismissKeyboard()
            next()
        }
        
        return true
    }
    
    
    // MARK: Private Methods
    
    @discardableResult
    private func check() -> Bool {
        urlTb.status = url == nil ? .bad : .good
        usernameTb.status = usernameTb.text?.isEmpty ?? true ? .bad : .good
        passwordTb.status = passwordTb.text?.isEmpty ?? true ? .bad : .good
        
        return urlTb.status == .good && usernameTb.status == .good && passwordTb.status == .good
        
    }
}

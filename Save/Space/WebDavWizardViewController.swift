//
//  WebDavWizardViewController.swift
//  Save
//
//  Created by Benjamin Erhart on 23.11.23.
//  Copyright © 2023 Open Archive. All rights reserved.
//

import UIKit
import CleanInsightsSDK
import FavIcon

class WebDavWizardViewController: BaseViewController, WizardDelegatable, TextBoxDelegate {

    var delegate: WizardDelegate?


    @IBOutlet weak var iconIv: UIImageView!

    @IBOutlet weak var titleLb: UILabel! {
        didSet {
            titleLb.text = NSLocalizedString("Private (WebDAV) Server", comment: "")
        }
    }

    @IBOutlet weak var subtitleLb: UILabel! {
        didSet {
            subtitleLb.text = String(
                format: NSLocalizedString("%1$@ only connects to WebDAV-compatible servers, e.g. Nextcloud and ownCloud.",
                                          comment: "First placeholder is app name"),
                Bundle.main.displayName)
        }
    }

    @IBOutlet weak var serverLb: UILabel! {
        didSet {
            serverLb.text = NSLocalizedString("Server Info", comment: "")
        }
    }

    @IBOutlet weak var urlTb: TextBox! {
        didSet {
            urlTb.placeholder = NSLocalizedString("Server URL", comment: "")
            urlTb.delegate = self
            urlTb.autocorrectionType = .no
            urlTb.autocapitalizationType = .none
        }
    }

    @IBOutlet weak var nameTb: TextBox! {
        didSet {
            nameTb.placeholder = NSLocalizedString("Server Name (Optional)", comment: "")
            nameTb.delegate = self
            nameTb.autocorrectionType = .no
            nameTb.autocapitalizationType = .none
        }
    }

    @IBOutlet weak var accountLb: UILabel! {
        didSet {
            accountLb.text = NSLocalizedString("Account", comment: "")
        }
    }

    @IBOutlet weak var usernameTb: TextBox! {
        didSet {
            usernameTb.placeholder = NSLocalizedString("Username", comment: "")
            usernameTb.delegate = self
            usernameTb.autocorrectionType = .no
            usernameTb.autocapitalizationType = .none
        }
    }

    @IBOutlet weak var passwordTb: TextBox! {
        didSet {
            passwordTb.placeholder = NSLocalizedString("Password", comment: "")
            passwordTb.delegate = self
            passwordTb.autocorrectionType = .no
            passwordTb.autocapitalizationType = .none
            passwordTb.status = .reveal
        }
    }

    @IBOutlet weak var nextcloudLb: UILabel! {
        didSet {
            nextcloudLb.text = NSLocalizedString("Use Upload Chunking (Nextcloud Only)", comment: "")
        }
    }

    @IBOutlet weak var nextcloudSw: UISwitch!

    @IBOutlet weak var nextcloudDescLb: UILabel! {
        didSet {
            nextcloudDescLb.text = NSLocalizedString(
                "\"Chunking\" uploads media in pieces so you don't have to restart your upload if your connection is interrupted.",
                comment: "")
        }
    }

    @IBOutlet weak var backBt: UIButton! {
        didSet {
            backBt.setTitle(NSLocalizedString("Back", comment: ""))
        }
    }

    @IBOutlet weak var nextBt: UIButton! {
        didSet {
            nextBt.setTitle(NSLocalizedString("Next", comment: ""))
        }
    }


    private lazy var workingOverlay: WorkingOverlay = {
        return WorkingOverlay().addToSuperview(navigationController?.view ?? view)
    }()

    private var url: URL? {
        Formatters.URLFormatter.fix(url: urlTb.text)
    }

    private var iconLoaded = false


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    @IBAction func back() {
        delegate?.back()
    }

    @IBAction func next() {
        guard check() else {
            return
        }

        let space = WebDavSpace(
            name: nameTb.text,
            url: url,
            favIcon: iconLoaded ? iconIv.image : nil,
            username: usernameTb.text,
            password: passwordTb.text)

        space.isNextcloud = nextcloudSw.isOn

        workingOverlay.isHidden = false

        // Do a test request to check validity of space configuration.
        space.session.info(space.url!) { [weak self] info, error in
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

                    CleanInsights.shared.measure(event: "backend", "new", forCampaign: "upload_fails", name: "WebDAV")

                    let vc = UIStoryboard.main.instantiate(SpaceSuccessViewController.self)
                    vc.spaceName = space.prettyName

                    self?.delegate?.next(vc, pos: 2)
                }
            }
        }
    }


    // MARK: TextBoxDelegate

    func textBox(didUpdate textBox: TextBox) {
        urlTb.text = url?.absoluteString

        if let baseUrl = Formatters.URLFormatter.fix(url: urlTb.text, baseOnly: true) {
            FavIcon.downloadSession = URLSession.withImprovedConf()

            try! FavIcon.downloadPreferred(baseUrl) { [weak self] result in
                if case let .success(image) = result {
                    self?.iconIv.image = image
                    self?.iconIv.contentMode = .scaleAspectFill
                    self?.iconLoaded = true
                }
            }
        }
    }

    func textBox(shouldReturn textBox: TextBox) -> Bool {
        switch textBox {
        case urlTb:
            nameTb.becomeFirstResponder()

        case nameTb:
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

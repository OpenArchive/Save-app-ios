//
//  IaScrapeViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import WebKit

protocol ScrapeDelegate {
    func scraped(accessKey: String, secretKey: String)
}

class IaScrapeViewController: BaseViewController, WKUIDelegate, WKNavigationDelegate {

    private static let keysUrl = URL(string: "https://archive.org/account/s3.php")!


    var delegate: ScrapeDelegate?

    private var accessKey: String?
    private var secretKey: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = IaSpace.defaultPrettyName

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(dismiss(_:)))

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh, target: self, action: #selector(load))

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        // Increase security: Although it currently seems like archive.org doesn't link away to any other site,
        // set this, so users don't accidentally go astray and catch themselves an ugly script.
        if #available(iOS 14.0, *) {
            configuration.limitsNavigationsToAppBoundDomains = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self

        view = webView
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        load()
    }


    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("$(':contains(\"access key\")').last().text().match(/^.*\\s(.+)$/)[1]") { object, error in
            if error == nil {
                self.accessKey = object as? String
                self.callDelegateIfReady()
            }
        }

        webView.evaluateJavaScript("$(':contains(\"secret key\")').last().text().match(/^.*\\s(.+)$/)[1]") { object, error in
            if error == nil {
                self.secretKey = object as? String
                self.callDelegateIfReady()
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        AlertHelper.present(self, message: error.friendlyMessage)
    }


    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        AlertHelper.present(self, message: error.friendlyMessage)
    }


    // MARK: Actions

    @objc func load() {
        if let webView = view as? WKWebView {
            webView.load(URLRequest(url: Self.keysUrl))
        }
    }


    // MARK: Private Methods

    private func callDelegateIfReady() {
        if let accessKey = accessKey, !accessKey.isEmpty,
           let secretKey = secretKey, !secretKey.isEmpty
        {
            self.delegate?.scraped(accessKey: accessKey, secretKey: secretKey)
        }
    }
}

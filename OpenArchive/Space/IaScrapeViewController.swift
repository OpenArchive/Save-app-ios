//
//  IaScrapeViewController.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 28.06.19.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import UIKit
import WebKit
import IPtProxyUI

protocol ScrapeDelegate {
    func scraped(accessKey: String, secretKey: String)
}

class IaScrapeViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    var delegate: ScrapeDelegate?

    private var accessKey: String?
    private var secretKey: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Internet Archive", comment: "")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh, target: self, action: #selector(load))

        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
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
            webView.load(URLRequest(url: InternetArchiveViewController.keysUrl))
        }
    }


    // MARK: Private Methods

    private func callDelegateIfReady() {
        if let accessKey = accessKey,
            let secretKey = secretKey {

            self.delegate?.scraped(accessKey: accessKey, secretKey: secretKey)
        }
    }
}

//
//  URLSession+Utils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.04.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Foundation

#if canImport(Tor)
import Tor
#endif

enum SaveError: Error {

    case invalidResponse

    case http(status: Int)
}

extension URLSession {

    class func withImprovedConf(configuration: URLSessionConfiguration? = nil, delegate: URLSessionDelegate? = nil) -> URLSession {
        URLSession(configuration: improvedConf(configuration), delegate: delegate, delegateQueue: nil)
    }

    class func improvedConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        let conf = conf ?? URLSessionConfiguration.default

        conf.sharedContainerIdentifier = Constants.appGroup

        // Fix error "CredStore - performQuery - Error copying matching creds."
        conf.urlCredentialStorage = nil

#if canImport(Tor)
        if Settings.useTor {
            conf.connectionProxyDictionary = [
                kCFProxyTypeKey: kCFProxyTypeSOCKS,
                kCFStreamPropertySOCKSProxyHost: "localhost",
                kCFStreamPropertySOCKSProxyPort: TorManager.shared.port,
                kCFStreamPropertySOCKSVersion: kCFStreamSocketSOCKSVersion5,
            ]
        }
#endif

//        print("[\(String(describing: type(of: self)))] sessionConf=[identifier=\(conf.identifier ?? "(nil)"), requestCachePolicy=\(conf.requestCachePolicy), timeoutIntervalForRequest=\(conf.timeoutIntervalForRequest), timeoutIntervalForResource=\(conf.timeoutIntervalForResource), networkServiceType=\(conf.networkServiceType), allowsCellularAccess=\(conf.allowsCellularAccess), waitsForConnectivity=\(conf.waitsForConnectivity), isDiscretionary=\(conf.isDiscretionary), sharedContainerIdentifier=\(conf.sharedContainerIdentifier ?? "(nil)"), sessionSendsLaunchEvents=\(conf.sessionSendsLaunchEvents), connectionProxyDictionary=\(conf.connectionProxyDictionary ?? [:]), tlsMinimumSupportedProtocol=\(conf.tlsMinimumSupportedProtocol), httpShouldUsePipelining=\(conf.httpShouldUsePipelining), httpShouldSetCookies=\(conf.httpShouldSetCookies), httpCookieAcceptPolicy=\(conf.httpCookieAcceptPolicy), httpAdditionalHeaders=\(conf.httpAdditionalHeaders ?? [:]), httpMaximumConnectionsPerHost=\(conf.httpMaximumConnectionsPerHost), httpCookieStorage=\(String(describing: conf.httpCookieStorage)), urlCredentialStorage=\(String(describing: conf.urlCredentialStorage)), urlCache=\(String(describing: conf.urlCache)), shouldUseExtendedBackgroundIdleMode=\(conf.shouldUseExtendedBackgroundIdleMode), protocolClasses=\(conf.protocolClasses ?? []), multipathServiceType=\(conf.multipathServiceType)]")

        return conf
    }

    @discardableResult
    func upload(_ file: URL, to: URL, method: String? = "POST", headers: [String: String]? = nil,
                completionHandler: ((_ error: Error?) -> Void)? = nil) -> URLSessionUploadTask
    {
        let request = request(to, method, headers)
        let task: URLSessionUploadTask

        if let completionHandler = completion(completionHandler) {
            task = uploadTask(with: request, fromFile: file,
                              completionHandler: completionHandler)
        }
        else {
            task = uploadTask(with: request, fromFile: file)
        }

        task.resume()

        return task
    }

    @discardableResult
    func upload(_ data: Data, to: URL, method: String? = "POST", headers: [String: String]? = nil,
                completionHandler: ((_ error: Error?) -> Void)? = nil) -> URLSessionUploadTask
    {
        let request = request(to, method, headers)
        let task: URLSessionUploadTask

        if let completionHandler = completion(completionHandler) {
            task = uploadTask(with: request, from: data,
                              completionHandler: completionHandler)
        }
        else {
            task = uploadTask(with: request, from: data)
        }

        task.resume()

        return task
    }

    @discardableResult
    func delete(_ url: URL, headers: [String: String]? = nil, completionHandler: ((_ error: Error?) -> Void)?) -> URLSessionDataTask
    {
        let request = request(url, "DELETE", headers)
        let task: URLSessionDataTask

        if let completionHandler = completion(completionHandler) {
            task = dataTask(with: request, completionHandler: completionHandler)
        }
        else {
            task = dataTask(with: request)
        }

        task.resume()

        return task
    }


    // MARK: Private Methods

    private func request(_ to: URL, _ method: String?, _ headers: [String: String]?) -> URLRequest {
        var request = URLRequest(url: to)
        request.httpMethod = method

        for header in headers ?? [:] {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }

        return request
    }

    private func completion(_ handler: ((Error?) -> Void)?) -> ((Data?, URLResponse?, Error?) -> Void)? {
        guard let handler = handler else {
            return nil
        }

        return { data, response, error in
            if let error = error {
                handler(error)

                return
            }

            guard let response = response as? HTTPURLResponse else {
                handler(SaveError.invalidResponse)

                return
            }

            if response.statusCode < 200 || response.statusCode >= 300 {
                handler(SaveError.http(status: response.statusCode))
            }

            handler(nil)
        }
    }
}

//
//  URLSession+Utils.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.04.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Foundation

enum SaveError: Error, LocalizedError {

    case strangeResponse

    case http(status: Int)

    var errorDescription: String? {
        switch self {
        case .strangeResponse:
            return "Strange response from server."

        case .http(let status):
            return "HTTP error: \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))"
        }
    }
}

extension URLSessionConfiguration {

    class func improved(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        let conf = conf ?? URLSessionConfiguration.ephemeral

        conf.sharedContainerIdentifier = Constants.appGroup

        // Fix error "CredStore - performQuery - Error copying matching creds."
        conf.urlCredentialStorage = nil

        // Disable all caching. Not really useful in our context and just leads to
        // cache remnants which pose a security risk.
        conf.urlCache = nil
        conf.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

//        print("[\(String(describing: type(of: self)))] sessionConf=[identifier=\(conf.identifier ?? "(nil)"), requestCachePolicy=\(conf.requestCachePolicy), timeoutIntervalForRequest=\(conf.timeoutIntervalForRequest), timeoutIntervalForResource=\(conf.timeoutIntervalForResource), networkServiceType=\(conf.networkServiceType), allowsCellularAccess=\(conf.allowsCellularAccess), waitsForConnectivity=\(conf.waitsForConnectivity), isDiscretionary=\(conf.isDiscretionary), sharedContainerIdentifier=\(conf.sharedContainerIdentifier ?? "(nil)"), sessionSendsLaunchEvents=\(conf.sessionSendsLaunchEvents), connectionProxyDictionary=\(conf.connectionProxyDictionary ?? [:]), tlsMinimumSupportedProtocol=\(conf.tlsMinimumSupportedProtocol), httpShouldUsePipelining=\(conf.httpShouldUsePipelining), httpShouldSetCookies=\(conf.httpShouldSetCookies), httpCookieAcceptPolicy=\(conf.httpCookieAcceptPolicy), httpAdditionalHeaders=\(conf.httpAdditionalHeaders ?? [:]), httpMaximumConnectionsPerHost=\(conf.httpMaximumConnectionsPerHost), httpCookieStorage=\(String(describing: conf.httpCookieStorage)), urlCredentialStorage=\(String(describing: conf.urlCredentialStorage)), urlCache=\(String(describing: conf.urlCache)), shouldUseExtendedBackgroundIdleMode=\(conf.shouldUseExtendedBackgroundIdleMode), protocolClasses=\(conf.protocolClasses ?? []), multipathServiceType=\(conf.multipathServiceType)]")

        return conf
    }
}

extension URLSession {

    typealias SimpleCompletionHandler = (_ error: Error?) -> Void

    @discardableResult
    func upload(_ file: URL, to: URL, method: String? = "PUT", headers: [String: String]? = nil,
                credential: URLCredential? = nil,
                completionHandler: SimpleCompletionHandler? = nil) -> URLSessionUploadTask
    {
        let request = request(to, method, addBasicAuth(headers, credential))
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
    func upload(_ data: Data, to: URL, method: String? = "PUT", headers: [String: String]? = nil,
                credential: URLCredential? = nil,
                completionHandler: SimpleCompletionHandler? = nil) -> URLSessionUploadTask
    {
        let request = request(to, method, addBasicAuth(headers, credential))
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
    func request(_ url: URL, method: String, headers: [String: String]? = nil, completionHandler: SimpleCompletionHandler? = nil) -> URLSessionDataTask
    {
        let request = request(url, method, headers)
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

    @discardableResult
    func delete(_ url: URL, headers: [String: String]? = nil, credential: URLCredential? = nil,
                completionHandler: SimpleCompletionHandler? = nil) -> URLSessionDataTask
    {
        return request(url, method: "DELETE", headers: addBasicAuth(headers, credential), completionHandler: completionHandler)
    }

    @discardableResult
    func mkDir(_ url: URL, credential: URLCredential? = nil, completionHandler: SimpleCompletionHandler? = nil) -> URLSessionDataTask
    {
        return request(url, method: "MKCOL", headers: addBasicAuth(nil, credential), completionHandler: completionHandler)
    }

    @discardableResult
    func move(_ url: URL, to: URL, credential: URLCredential? = nil, completionHandler: SimpleCompletionHandler? = nil) -> URLSessionDataTask
    {
        return request(url, method: "MOVE", headers: addBasicAuth(["Destination": to.absoluteString], credential), completionHandler: completionHandler)
    }

    @discardableResult
    func info(_ url: URL, credential: URLCredential? = nil, completionHandler: ((_ info: [FileInfo], _ error: Error?) -> Void)?) -> URLSessionDataTask {
        let request = request(url, "PROPFIND", addBasicAuth(["Depth": "1"], credential))

        let task: URLSessionDataTask

        if let handler = completionHandler {
            task = dataTask(with: request) { data, response, error in
                var info = [FileInfo]()

                if let data = data, !data.isEmpty {
                    info = DavResponse.parse(xmlResponse: data, baseURL: nil).map { FileInfo($0) }
                }

                if let error = error {
                    handler(info, error)

                    return
                }

                guard let response = response as? HTTPURLResponse else {
                    handler(info, SaveError.strangeResponse)

                    return
                }

                if response.statusCode < 200 || response.statusCode >= 300 {
                    handler(info, SaveError.http(status: response.statusCode))

                    return
                }

                handler(info, nil)
            }
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
                handler(SaveError.strangeResponse)

                return
            }

            if response.statusCode < 200 || response.statusCode >= 300 {
                handler(SaveError.http(status: response.statusCode))

                return
            }

            handler(nil)
        }
    }

    /**
     Create a HTTP Basic Auth header from the provided credentials, if valid.

     - parameter headers: A headers dictionary where to add our auth header to.
     - parameter credential: Credential to use.
     - returns: nil, if headers was nil and no valid credential, otherwise a header
        dictionary with an added (potentially overwritten) "Authorization" header.
    */
    private func addBasicAuth(_ headers: [String: String]?, _ credential: URLCredential?) -> [String: String]? {
        var headers = headers

        if let basicAuth = credential?.basicAuth {
            if headers == nil {
                headers = [:]
            }

            headers!["Authorization"] = basicAuth
        }

        return headers
    }
}

extension URLCredential {

    /**
     Returns an HTTP basic authentication string.
     */
    var basicAuth: String? {
        guard let user = user, !user.isEmpty,
              let password = password, !password.isEmpty,
              let authorization = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
        else {
            return nil
        }

        return "Basic \(authorization)"
    }
}

//
//  SessionManager+improvedConf.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 27.04.22.
//  Copyright © 2022 Open Archive. All rights reserved.
//

import Alamofire

#if canImport(Tor)
import Tor
#endif

extension SessionManager {

    class func withImprovedConf(configuration: URLSessionConfiguration? = nil, delegate: SessionDelegate) -> SessionManager {
        SessionManager(configuration: improvedConf(configuration), delegate: delegate)
    }

    class func improvedConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        let conf = conf ?? URLSessionConfiguration.default

        conf.sharedContainerIdentifier = Constants.appGroup

        // Fix error "CredStore - performQuery - Error copying matching creds."
        conf.urlCredentialStorage = nil

        conf.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

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
}

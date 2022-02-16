//
//  TorManager.swift
//  OpenArchive
//
//  Created by Benjamin Erhart on 11.02.22.
//  Copyright © 2019 Open Archive. All rights reserved.
//

import NetworkExtension
import Tor
import IPtProxyUI
import Alamofire

extension Notification.Name {

    static let torUseChanged = Notification.Name(rawValue: "\(Bundle.main.bundleIdentifier!).torUseChanged")
    
    static let torError = Notification.Name(rawValue: "\(Bundle.main.bundleIdentifier!).torError")

    static let torStartProgress = Notification.Name(rawValue: "\(Bundle.main.bundleIdentifier!).torStartProgress")

    static let torStarted = Notification.Name(rawValue: "\(Bundle.main.bundleIdentifier!).torStarted")

    static let torStopped = Notification.Name(rawValue: "\(Bundle.main.bundleIdentifier!).torStopped")
}

class TorManager {

    private enum Errors: Error {
        case cookieUnreadable
        case noSocksAddr
    }

    static let shared = TorManager()


    public var connected: Bool {
        (torThread?.isExecuting ?? false)
        && (torConf?.isLocked ?? false)
        && (torController?.isConnected ?? false)
    }

    public var started: Bool {
        connected && port > 0
    }


    private var torThread: TorThread?

    private var torController: TorController?

    private var torConf: TorConfiguration?

    private lazy var controllerQueue = DispatchQueue.global(qos: .userInitiated)

    private var transport = Transport.none

    private var ipStatus = IpSupport.Status.unavailable

    private var port = 0


    private init() {
        IpSupport.shared.start({ [weak self] status in
            self?.ipStatus = status

            if self?.connected ?? false {
                self?.torController?.setConfs(status.torConf(self?.transport ?? .none, Transport.asConf))
                { success, error in
                    if let error = error {
                        print("[\(String(describing: type(of: self)))] error: \(error)")
                    }

                    self?.torController?.resetConnection()
                }
            }
        })
    }

    func start() {
        guard !connected else {
            return
        }

        transport = Settings.transport
        transport.start()

        torConf = getTorConf()

        torThread = TorThread(configuration: torConf)

        torThread?.start()

        controllerQueue.asyncAfter(deadline: .now() + 0.65) {
            let nc = NotificationCenter.default

            if self.torController == nil, let url = self.torConf?.controlPortFile {
                self.torController = TorController(controlPortFile: url)
            }

            if !(self.torController?.isConnected ?? false) {
                do {
                    try self.torController?.connect()
                }
                catch let error {
                    print("[\(String(describing: type(of: self)))] error=\(error)")

                    return nc.post(name: .torError, object: error)
                }
            }

            guard let cookie = self.torConf?.cookie else {
                print("[\(String(describing: type(of: self)))] cookie unreadable")

                return nc.post(name: .torError, object: Errors.cookieUnreadable)
            }

            self.torController?.authenticate(with: cookie) { success, error in
                if let error = error {
                    print("[\(String(describing: type(of: self)))] error=\(error)")

                    return nc.post(name: .torError, object: error)
                }

                var progressObs: Any?
                progressObs = self.torController?.addObserver(forStatusEvents: {
                    (eventType, severity, action, arguments) -> Bool in

                    if eventType == "STATUS_CLIENT" && action == "BOOTSTRAP" {
                        let progress = Int(arguments!["PROGRESS"]!)!
                        print("[\(String(describing: type(of: self)))] progress=\(progress)")

                        nc.post(name: .torStartProgress, object: progress)

                        if progress >= 100 {
                            self.torController?.removeObserver(progressObs)
                        }

                        return true
                    }

                    return false
                })

                var observer: Any?
                observer = self.torController?.addObserver(forCircuitEstablished: { established in
                    guard established else {
                        return
                    }

                    self.torController?.removeObserver(observer)

                    self.torController?.getInfoForKeys(["net/listeners/socks"]) { response in
                        guard let socksAddr = response.first,
                                !socksAddr.isEmpty,
                              let portStr = socksAddr.split(separator: ":").last,
                              let port = Int(portStr)
                        else {
                            nc.post(name: .torError, object: Errors.noSocksAddr)

                            return self.stop()
                        }

                        self.port = port

                        nc.post(name: .torStarted, object: nil)
                    }
                })
            }
        }
    }

    /**
     Will reconfigure Tor with changed bridge configuration, if it is already running.

     ATTENTION: If Tor is currently starting up, nothing will change.
     */
    func reconfigureBridges() {
        transport = Settings.transport

        guard connected else {
            return // Nothing can be done. Will get configured on (next) start.
        }

        torController?.resetConf(forKey: "UseBridges")
        { [weak self] _, error in
            if let error = error {
                print("[\(String(describing: type(of: self)))] error=\(error)")

                return
            }

            self?.torController?.resetConf(forKey: "ClientTransportPlugin")
            { _, error in
                if let error = error {
                    print("[\(String(describing: type(of: self)))] error=\(error)")

                    return
                }

                self?.torController?.resetConf(forKey: "Bridge")
                { _, error in
                    if let error = error {
                        print("[\(String(describing: type(of: self)))] error=\(error)")

                        return
                    }

                    guard let transport = self?.transport else {
                        return
                    }

                    switch transport {
                    case .obfs4, .custom:
                        Transport.snowflake.stop()

                    case .snowflake, .snowflakeAmp:
                        Transport.obfs4.stop()

                    default:
                        Transport.obfs4.stop()
                        Transport.snowflake.stop()
                    }

                    guard transport != .none else {
                        return
                    }

                    transport.start()

                    var conf = transport.torConf(Transport.asConf)
                    conf.append(Transport.asConf(key: "UseBridges", value: "1"))

                    self?.torController?.setConfs(conf)
                }
            }
        }
    }

    func sessionConf(_ conf: URLSessionConfiguration? = nil) -> URLSessionConfiguration {
        let conf = conf ?? URLSessionConfiguration.default

        conf.sharedContainerIdentifier = Constants.appGroup

        // Fix error "CredStore - performQuery - Error copying matching creds."
        conf.urlCredentialStorage = nil

        conf.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders

        if Settings.useTor {
            conf.connectionProxyDictionary = [
                kCFProxyTypeKey: kCFProxyTypeSOCKS,
                kCFStreamPropertySOCKSProxyHost: "localhost",
                kCFStreamPropertySOCKSProxyPort: port,
                kCFStreamPropertySOCKSVersion: kCFStreamSocketSOCKSVersion5,
            ]
        }

//        print("[\(String(describing: type(of: self)))] sessionConf=[identifier=\(conf.identifier ?? "(nil)"), requestCachePolicy=\(conf.requestCachePolicy), timeoutIntervalForRequest=\(conf.timeoutIntervalForRequest), timeoutIntervalForResource=\(conf.timeoutIntervalForResource), networkServiceType=\(conf.networkServiceType), allowsCellularAccess=\(conf.allowsCellularAccess), waitsForConnectivity=\(conf.waitsForConnectivity), isDiscretionary=\(conf.isDiscretionary), sharedContainerIdentifier=\(conf.sharedContainerIdentifier ?? "(nil)"), sessionSendsLaunchEvents=\(conf.sessionSendsLaunchEvents), connectionProxyDictionary=\(conf.connectionProxyDictionary ?? [:]), tlsMinimumSupportedProtocol=\(conf.tlsMinimumSupportedProtocol), httpShouldUsePipelining=\(conf.httpShouldUsePipelining), httpShouldSetCookies=\(conf.httpShouldSetCookies), httpCookieAcceptPolicy=\(conf.httpCookieAcceptPolicy), httpAdditionalHeaders=\(conf.httpAdditionalHeaders ?? [:]), httpMaximumConnectionsPerHost=\(conf.httpMaximumConnectionsPerHost), httpCookieStorage=\(String(describing: conf.httpCookieStorage)), urlCredentialStorage=\(String(describing: conf.urlCredentialStorage)), urlCache=\(String(describing: conf.urlCache)), shouldUseExtendedBackgroundIdleMode=\(conf.shouldUseExtendedBackgroundIdleMode), protocolClasses=\(conf.protocolClasses ?? []), multipathServiceType=\(conf.multipathServiceType)]")

        return conf
    }

    func stop() {
        port = 0

        transport.stop()

        torController?.disconnect()
        torController = nil

        torThread?.cancel()
        torThread = nil

        torConf = nil

        NotificationCenter.default.post(name: .torStopped, object: nil)
    }

    func getCircuits(_ completion: @escaping ([TorCircuit]) -> Void) {
        torController?.getCircuits(completion)
    }

    func close(_ circuits: [TorCircuit], _ completion: ((Bool) -> Void)?) {
        torController?.close(circuits, completion: completion)
    }


    // MARK: Private Methods

    private func getTorConf() -> TorConfiguration {
        let conf = TorConfiguration()

        conf.ignoreMissingTorrc = true
        conf.cookieAuthentication = true
        conf.autoControlPort = true
        conf.clientOnly = true
        conf.avoidDiskWrites = true
        conf.dataDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tor", isDirectory: true)

        conf.arguments += transportConf(Transport.asArguments).joined()

        conf.arguments += ipStatus.torConf(transport, Transport.asArguments).joined()

        conf.options = [
            // Log
            "Log": "notice stdout",
            "LogMessageDomains": "1",
            "SafeLogging": "1",

            // SOCKS5
            "SocksPort": "auto"]

        return conf
    }

    private func transportConf<T>(_ cv: (String, String) -> T) -> [T] {

        var arguments = transport.torConf(cv)

        if transport == .custom, let bridgeLines = Settings.customBridges {
            arguments += bridgeLines.map({ cv("Bridge", $0) })
        }

        arguments.append(cv("UseBridges", transport == .none ? "0" : "1"))

        return arguments
    }
}

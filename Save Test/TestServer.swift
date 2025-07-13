import Foundation
import Network
import XCTest

extension Notification.Name {
    static let TestServerRequestReceived = Notification.Name("TestServerRequestReceived")
    
    static let TestServerResponseSent = Notification.Name("TestServerResponseSent")
    
    static let TestServerConnectionComplete = Notification.Name("TestServerConnectionComplete")
}

let testServer = TestServer(port: 8080)

class TestServer {
    private var listener: NWListener?
    let port: UInt16
    private let serverQueue = DispatchQueue(label: "TestServerQueue")
    private let actor = TestServerActor()
    private var isReady = false
        
    init(port: UInt16 = 8080) {
        self.port = port
    }
    
    func start() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.allowFastOpen = true
            
            do {
                listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
                
                listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        print("Test Server ready on port \(self?.port ?? 0)")
                        self?.isReady = true
                        continuation.resume()
                    case .failed(let error):
                        print("Test Server failed with error: \(error)")
                        continuation.resume(throwing: error)
                    case .cancelled:
                        print("Test Server cancelled")
                    default:
                        break
                    }
                }
                
                listener?.newConnectionHandler = { [weak self] connection in
                    self?.handleNewConnection(connection)
                }
                
                listener?.start(queue: serverQueue)
            } catch {
                print("Failed to create listener: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    func stop() async {
        self.listener?.cancel()
        await self.actor.cancelPendingRequest()
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(on: connection)
            case .preparing:
                break
            case .waiting(let error):
                print("Connection state: Waiting - Error: \(error)")
            case .failed(let error):
                print("Connection failed: \(error)")
            case .cancelled:
                print("Connection cancelled")
            case .setup:
                print("Connection state: Setup")
            @unknown default:
                print("Connection state: Unknown")
            }
        }
        
        connection.start(queue: serverQueue)
    }
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("Receive error: \(error)")
                connection.cancel()
                return
            }

            if let data = content {
                guard let request = self.parseHTTPRequest(String(decoding: data, as: UTF8.self)) else {
                    print("Failed to parse HTTP request")
                    connection.cancel()
                    return
                }

                NotificationCenter.default.post(name: .TestServerRequestReceived, object: self, userInfo: ["request": request])

                guard let response = self.generateHTTPResponse(for: request) else {
                    print("Failed to generate HTTP response")
                    connection.cancel()
                    return
                }

                NotificationCenter.default.post(name: .TestServerResponseSent, object: self, userInfo: ["response": response])

                connection.send(content: response.data(using: .utf8), isComplete: true, completion: .contentProcessed { sendError in
                    if let sendError = sendError {
                        print("Send error: \(sendError)")
                    }
                    connection.cancel()
                })
            } else {
                print("No data received")
                connection.cancel()
            }

            // If more data is expected, schedule another receive
            if !isComplete && connection.state == .ready {
                DispatchQueue.global().async {
                    self.receiveData(on: connection)
                }
            }
        }
    }

    func parseHTTPRequest(_ raw: String) -> Request? {
        let sections = raw.components(separatedBy: "\r\n\r\n")
        guard sections.count >= 1 else {
            return nil
        }
        
        let headerBlock = sections[0]
        let body = sections.dropFirst().joined(separator: "\r\n\r\n")
        
        let headerLines = headerBlock.components(separatedBy: "\r\n")
        let startLine = headerLines.first ?? ""
        
        let requestParts = startLine.components(separatedBy: " ")
        
        guard requestParts.count >= 2 else {
            return nil
        }
        
        let headers = headerLines.dropFirst().reduce(into: [String: String]()) { dict, line in
            let parts = line.components(separatedBy: ": ")
            if parts.count == 2 {
                dict[parts[0]] = parts[1]
            }
        }
        
        return Request(
            method: requestParts[0],
            url: requestParts[1],
            headers: headers,
            body: body.isEmpty ? nil : body.data(using: .utf8)
        )
    }
    
    func generateHTTPResponse(for request: Request) -> String? {
        let statusLine: String
        let headers: [String: String] = [
            "Content-Length": "0",
            "Connection": "close",
            "Server": "TestServer"
        ]
        
        if request.method == "PUT" || request.method == "POST" {
            statusLine = "HTTP/1.1 201 Created"
        } else {
            statusLine = "HTTP/1.1 200 OK"
        }
        
        var response = "\(statusLine)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        
        return response
    }
    
    func waitForRequest(filter: ((Request) -> Bool)? = nil) async throws -> Request {
        return try await actor.waitForRequest(filter: filter)
    }

    struct Request {
        let method: String
        let url: String
        let headers: [String: String]
        let body: Data?
        
        init(method: String, url: String, headers: [String: String] = [:], body: Data? = nil) {
            self.method = method
            self.url = url
            self.headers = headers
            self.body = body
        }
    }
    
    actor TestServerActor {
        private var continuation: CheckedContinuation<Request, Error>?
        private var observer: NSObjectProtocol?

        func waitForRequest(filter: ((Request) -> Bool)? = nil) async throws -> Request {
            return try await withCheckedThrowingContinuation { cont in
                self.continuation = cont

                self.observer = NotificationCenter.default.addObserver(
                    forName: .TestServerRequestReceived,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    Task {
                        await self?.handle(notification: notification, filter: filter)
                    }
                }
            }
        }

        private func handle(notification: Notification, filter: ((Request) -> Bool)?) {
            guard let cont = continuation else { return }

            // Clean up
            continuation = nil
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }

            if let request = notification.userInfo?["request"] as? Request {
                if let filter = filter, !filter(request) {
                    cont.resume(throwing: NSError(domain: "TestServerError", code: 2,
                                                  userInfo: [NSLocalizedDescriptionKey: "Request did not pass filter"]))
                } else {
                    cont.resume(returning: request)
                }
            } else {
                cont.resume(throwing: NSError(domain: "TestServerError", code: 1,
                                              userInfo: [NSLocalizedDescriptionKey: "Invalid request payload"]))
            }
        }
        
        func cancelPendingRequest() {
            if let cont = continuation {
                continuation = nil
                cont.resume(throwing: NSError(domain: "TestServerError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]))
            }
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }

    }

}

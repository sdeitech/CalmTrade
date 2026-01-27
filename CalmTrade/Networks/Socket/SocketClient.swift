//
//  SocketClient.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/10/25.
//

import Foundation
import SocketIO

final class SocketClient: NSObject {
    static let shared = SocketClient()
    private override init() {}

    deinit {
        disconnect()  // Ensure cleanup when SocketClient is deallocated
    }

    // MARK: - Config
    private var baseURL: URL { BuildConfig.websocketURL }  // keep using your existing config

    /// If your Socket.IO server runs on a subpath, set it here (default: /socket.io)
    private let socketPath: String = "/socket.io"

    // MARK: - State
    private var token: String?
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    // MARK: - Public API (unchanged)
    func connect(with token: String) {
        self.token = token

        // Build SocketManager with auth + options
        var cfg: SocketIOClientConfiguration = [
            .log(true),
            .path(socketPath),
            .reconnects(true),
            .reconnectWait(2),
            .reconnectAttempts(-1),           // infinite
            .forceNew(true),
            .forceWebsockets(true)            // skip polling if you want only WS
        ]

        // Auth: Either headers or connectParams (match your backend)
        cfg.insert(.extraHeaders(["Authenticate": token]))
        // OR: cfg.insert(.connectParams(["Authorization": token]))

        // TLS note: if you're using https://, useSecure must be true
        if baseURL.scheme?.lowercased() == "https" {
            cfg.insert(.secure(true))
        }

        manager = SocketManager(socketURL: baseURL, config: cfg)
        socket  = manager?.defaultSocket

        // --- Event wiring ---
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            NSLog("🟢 Socket.IO connected → emitting 'connection' & 'Authenticate'")

            // 1) announce connection
            self.emit(key: "connection", payload: ["ts": Int(Date().timeIntervalSince1970)])

            // 2) authenticate (capital A)
            if let t = self.token, !t.isEmpty {
                self.emit(key: "Authenticate", payload: ["token": t])
            }
        }

        socket?.on(clientEvent: .error) { data, _ in
            NSLog("🔴 Socket.IO error: \(data)")
        }

        socket?.on(clientEvent: .disconnect) { data, _ in
            NSLog("🟠 Socket.IO disconnected: \(data)")
        }

        // Example server push handlers (adjust to the events your server emits)
        socket?.on("connection-ack") { data, _ in
            NSLog("🟢 server ack’d connection \(data)")
        }
        socket?.on("auth-ok") { data, _ in
            NSLog("🟢 server authenticated token \(data)")
        }
        socket?.on("auth-error") { [weak self] data, _ in
            NSLog("🔴 auth failed \(data)")
            self?.disconnect()
        }
        socket?.on("server-disconnect") { [weak self] data, _ in
            NSLog("🟠 server requested disconnect \(data)")
            self?.disconnect()
        }

        // Connect
        NSLog("🔵 Socket.IO connecting → \(baseURL.absoluteString)\(socketPath)")
        socket?.connect()
    }

    func disconnect() {
        // Emit your logical disconnect (server can listen to this)
        emit(key: "disconnect", payload: ["ts": Int(Date().timeIntervalSince1970)])

        // Clean up the socket and manager
        socket?.disconnect()
        socket?.removeAllHandlers()  // Remove all event handlers to prevent memory leaks
        manager = nil
        socket  = nil
        token   = nil
        NSLog("🟠 Socket.IO disconnect invoked")
    }

    /// Sends a message with your `{key, data}` schema over Socket.IO
    func send(key: String, payload: [String: Any]? = nil) {
        emit(key: key, payload: payload ?? [:])
    }

    // MARK: - Internal emit helper
    private func emit(key: String, payload: [String: Any]) {
        // Two common patterns. Pick the one your backend expects:

        // (A) Single channel (e.g. "message") with envelope {key,data}
        // socket?.emit("message", ["key": key, "data": payload])

        // (B) Event-per-key (simpler if your backend registers handlers by name)
        socket?.emit(key, payload)

//        NSLog("📤 emit \(key): \(payload)")
    }
}



//extension SocketClient: URLSessionWebSocketDelegate {
//    func urlSession(_ session: URLSession,
//                    webSocketTask: URLSessionWebSocketTask,
//                    didOpenWithProtocol `protocol`: String?) {
//        NSLog("🟢 WS connected to \(webSocketTask.currentRequest?.url?.absoluteString ?? "?")")
//        isConnecting = false
//        backoffIndex = 0
//        
//        // 1) announce connection
//        struct Conn: Codable { let ts: Int }
//        send(key: "connection", payload: Conn(ts: Int(Date().timeIntervalSince1970)))
//        
//        // 2) authenticate (capital A exactly as provided)
//        if let t = token, !t.isEmpty {
//            struct Auth: Codable { let token: String }
//            send(key: "Authenticate", payload: Auth(token: t))
//        }
//    }
//    
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
//                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
//        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
//        NSLog("🟠 WS closed (\(closeCode.rawValue)) reason: \(reasonStr)")
//        reconnectIfNeeded()
//    }
//}

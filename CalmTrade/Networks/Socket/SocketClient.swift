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
    private let stateQueue = DispatchQueue(label: "com.calmtrade.socketclient.state")
    private var token: String?
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    // MARK: - Public API (unchanged)
    func connect(with token: String) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return }

        stateQueue.async { [weak self] in
            self?.connectLocked(with: normalizedToken)
        }
    }

    func disconnect() {
        stateQueue.async { [weak self] in
            self?.disconnectLocked()
        }
    }

    /// Sends a message with your `{key, data}` schema over Socket.IO
    func send(key: String, payload: [String: Any]? = nil) {
        stateQueue.async { [weak self] in
            self?.emitLocked(key: key, payload: payload ?? [:])
        }
    }

    // MARK: - Internal state machine
    private func connectLocked(with token: String) {
        if self.token == token, let status = socket?.status, status == .connected || status == .connecting {
            return
        }

        if manager != nil || socket != nil {
            disconnectLocked(emitLogicalDisconnect: false)
        }

        self.token = token

        // Build SocketManager with auth + options
        var cfg: SocketIOClientConfiguration = [
            .log(false),
            .path(socketPath),
            .reconnects(true),
            .reconnectWait(2),
            .reconnectAttempts(-1),           // infinite
            .forceWebsockets(true)            // skip polling if you want only WS
        ]

        // Auth: Either headers or connectParams (match your backend)
        cfg.insert(.extraHeaders(["Authenticate": token]))
        // OR: cfg.insert(.connectParams(["Authorization": token]))

        // TLS note: if you're using https://, useSecure must be true
        if baseURL.scheme?.lowercased() == "https" {
            cfg.insert(.secure(true))
        }

        let manager = SocketManager(socketURL: baseURL, config: cfg)
        let socket = manager.defaultSocket
        self.manager = manager
        self.socket = socket

        // --- Event wiring ---
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }

            // 1) announce connection
            self.stateQueue.async {
                self.emitLocked(key: "connection", payload: ["ts": Int(Date().timeIntervalSince1970)])

                // 2) authenticate (capital A)
                if let t = self.token, !t.isEmpty {
                    self.emitLocked(key: "Authenticate", payload: ["token": t])
                }
            }
        }

        socket.on(clientEvent: .error) { _, _ in
        }

        socket.on(clientEvent: .disconnect) { _, _ in
        }

        // Example server push handlers (adjust to the events your server emits)
        socket.on("connection-ack") { _, _ in
        }
        socket.on("auth-ok") { _, _ in
        }
        socket.on("auth-error") { [weak self] _, _ in
            self?.disconnect()
        }
        socket.on("server-disconnect") { [weak self] _, _ in
            self?.disconnect()
        }

        // Connect
        socket.connect()
    }

    private func disconnectLocked(emitLogicalDisconnect: Bool = true) {
        if emitLogicalDisconnect {
            emitLocked(key: "disconnect", payload: ["ts": Int(Date().timeIntervalSince1970)])
        }

        socket?.disconnect()
        socket?.removeAllHandlers()
        manager = nil
        socket = nil
        token = nil
    }

    // MARK: - Internal emit helper
    private func emitLocked(key: String, payload: [String: Any]) {
        socket?.emit(key, payload)
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

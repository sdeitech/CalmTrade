//
//  DebugLog.swift
//  CalmTrade
//
//  Created by Anas Parekh on 16/09/25.
//


// DebugLog.swift
import Foundation
import os

final class DebugLog {
    static let shared = DebugLog()

    private let lock = NSLock()
    private var lines: [String] = []
    private let maxLines = 500

    /// Called on main whenever a new line arrives.
    var onChange: (() -> Void)?

    private init() {}

    @discardableResult
    func log(_ message: String) -> String {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(message)"
        lock.lock()
        lines.append(line)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        lock.unlock()

        // Mirror to system console (non-sensitive)
        if #available(iOS 14.0, *) {
            let logger = Logger(subsystem: "com.calmtrade.app", category: "diagnostics")
            logger.debug("\(message, privacy: .public)")
        } else {
            print(line)
        }

        DispatchQueue.main.async { self.onChange?() }
        return line
    }

    func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return lines
    }

    /// Writes current buffer to a temp .log file and returns the URL (for share sheet).
    func exportToTempFile() -> URL? {
        let name = "calmtrade_debug_\(Int(Date().timeIntervalSince1970)).log"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let contents = snapshot().joined(separator: "\n")
        do { try contents.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { _ = log("Export failed: \(error.localizedDescription)"); return nil }
    }
}

//
//  UserScope.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/11/25.
//


import Foundation

enum UserScope {
    static var userId: String? { SessionManager.shared.current?.id }

    // 2.1 Scoped UserDefaults (per account via suite name)
    static var defaults: UserDefaults {
        if let uid = userId,
           let suite = UserDefaults(suiteName: "com.your.bundle.user.\(uid)") {
            return suite
        }
        return UserDefaults.standard // fallback (pre-login / legacy)
    }

    // 2.2 Scoped App Support folder: .../Application Support/Users/<userId>/
    static var appSupportURL: URL {
        let fm = FileManager.default
        let base = try! fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask, appropriateFor: nil, create: true)
        let users = base.appendingPathComponent("Users", isDirectory: true)
        if !fm.fileExists(atPath: users.path) { try? fm.createDirectory(at: users, withIntermediateDirectories: true) }
        let path = users.appendingPathComponent(userId ?? "_anonymous", isDirectory: true)
        if !fm.fileExists(atPath: path.path) { try? fm.createDirectory(at: path, withIntermediateDirectories: true) }
        return path
    }

    // Useful helper for files you currently write into Documents/Caches
    static func file(in subdir: String, named name: String) -> URL {
        let dir = appSupportURL.appendingPathComponent(subdir, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(name, isDirectory: false)
    }
}

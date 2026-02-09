//
//  UserSession.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/11/25.
//  Updated by ChatGPT on 19/12/25
//

import Foundation
import Combine

/// Global user/session controller
final class SessionManager: ObservableObject {

    // MARK: - Shared Singleton
    static let shared = SessionManager()

    // MARK: - Published User (UI auto-updates everywhere)
    @Published private(set) var current: User? = nil

    // MARK: - Stored Token
    private(set) var accessToken: String? = nil

    private init() {
        loadFromStorage()
    }

    // MARK: - Public API

    /// Set the current logged-in user model and persist it
    func setCurrentUser(_ user: User?, token: String? = nil) {

        print("👤 setCurrentUser:", user?.id ?? "nil")

        self.current = user

        if let token, !token.isEmpty {
            self.accessToken = token
        }

//        persist()

        // 🚫 DO NOT revert to anonymous after login
        guard let user else { return }

//        NotificationCenter.default.post(
//            name: .userAccountDidChange,
//            object: user.id
//        )
    }

    /// Update only the token (e.g. refresh)
    func updateToken(_ token: String) {
        self.accessToken = token
        persist()
    }

    /// Clear session and broadcast logout
    func logout() {
        current = nil
        accessToken = nil
        clearStorage()
        NotificationCenter.default.post(name: .userAccountDidChange, object: nil)
    }

    // MARK: - Internal Persistence Layer

    private struct Keys {
        static let user = "ct.currentUser"
        static let token = "ct.accessToken"
    }

    /// Persist user + token using UserDefaults (Core Data optional)
    private func persist() {
        let ud = UserDefaults.standard

        if let user = current {
            if let data = try? JSONEncoder().encode(user) {
                ud.set(data, forKey: Keys.user)
            }
        } else {
            ud.removeObject(forKey: Keys.user)
        }

        if let t = accessToken {
            ud.set(t, forKey: Keys.token)
        } else {
            ud.removeObject(forKey: Keys.token)
        }

        ud.synchronize()
    }

    /// Load user/token back into memory on app launch
    private func loadFromStorage() {
        let ud = UserDefaults.standard

        if let data = ud.data(forKey: Keys.user),
           let decoded = try? JSONDecoder().decode(User.self, from: data) {
            self.current = decoded
        }

        if let token = ud.string(forKey: Keys.token) {
            self.accessToken = token
        }
    }

    /// Remove user + token permanently
    private func clearStorage() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: Keys.user)
        ud.removeObject(forKey: Keys.token)
        ud.synchronize()
    }
}

extension Notification.Name {
    static let userAccountDidChange = Notification.Name("UserAccountDidChange")
    static let authDidExpire = Notification.Name("authDidExpire")
}

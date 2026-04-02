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
        let previousUserId = current?.id

        print("👤 setCurrentUser:", user?.id ?? "nil")

        self.current = user

        if let token, !token.isEmpty {
            self.accessToken = token
        }

        persist()

        let nextUserId = user?.id
        guard previousUserId != nextUserId else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .userAccountDidChange, object: user)
        }
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .userAccountDidChange, object: nil)
        }
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

        if let token = ud.string(forKey: Keys.token) ?? ud.string(forKey: "accessToken") {
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
}

enum FeatureKey {

    // Core trading & analytics
    static let calmScoreGauge = "Calmscore gauge"
    static let tradeAnalyticsStats = "Trade Analytics + Stats"
    static let tradesHistory = "Trades history"
    static let manualTradeImport = "Manual trade import"
    static let multipleAccountHandling = "multiple account handling for trade imports"

    // Broker & sync
    static let brokerSync = "Broker Sync"
    static let realtime360Sync = "360 realtime sync"

    // Biometrics & health
    static let biometricDashboard = "Biometric dashboard"
    static let chartsForBiometric = "Charts for biometric"
    static let appleHealthKitSync = "Apple healthkit sync"

    // Emotions & journaling
    static let emotionTagging = "Emotion tagging"
    static let customEmotions = "Custom Emotions"
    static let journalUnlocked = "Journal (Unlocked)"

}

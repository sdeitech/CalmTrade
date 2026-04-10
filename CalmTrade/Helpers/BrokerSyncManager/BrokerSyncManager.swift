//
//  BrokerSyncManager.swift
//  CalmTrade
//
//  Created by Anas Parekh on 05/01/26.
//

import Foundation

final class BrokerSyncManager {

    static let shared = BrokerSyncManager()
    private let api = APIService()

    private var lastSyncAt: Date?
    private let minInterval: TimeInterval = 30   // seconds

    private init() {}

    func syncIfNeeded(
        fullSync: Bool = false,
        completion: (() -> Void)? = nil
    ) {
//        guard
//            let accountId = SessionManager.shared.current?.accountId
//        else {
//            completion?()
//            return
//        }

        // Throttle background syncs
        if let last = lastSyncAt,
           Date().timeIntervalSince(last) < minInterval {
            completion?()
            return
        }

        lastSyncAt = Date()

        let params: [String: Any] = [
//            "accountId": accountId,
            "fullSync": fullSync
        ]

        api.startService(
            with: .POST,
            path: "broker/sync",
            parameters: params,
            files: nil,
            modelType: EmptyResponse.self
        ) { _ in
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}


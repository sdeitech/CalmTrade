//
//  SleepHistoryStore.swift
//  CalmTrade
//
//  Unified sleep history provider.
//  Uses SleepRepository (ct360 > Apple Health) for all session logs.
//  NO HealthKit querying here.
//

import Foundation

final class SleepHistoryStore {
    static let shared = SleepHistoryStore()
    private init() {}

    // MARK: - PUBLIC API
    func fetchAllSessions(
        limit: Int? = nil,
        before endDate: Date = Date(),
        ascending: Bool = false
    ) -> [SleepLogEntry] {

        let startDate = Date.distantPast

        // Canonical sessions from SleepRepository (single source of truth).
        let summaries = SleepRepository.shared.unifiedSessions(from: startDate, to: endDate)
        let logs = summaries.map {
            SleepLogEntry(
                sessionStart: $0.sessionStart,
                sessionEnd: $0.sessionEnd,
                totalSeconds: $0.totalInBedSeconds,
                remSeconds: $0.remSeconds,
                coreSeconds: $0.coreSeconds,
                deepSeconds: $0.deepSeconds,
                awakeSeconds: $0.awakeSeconds,
                source: $0.source
            )
        }

        // Sort
        var sorted = logs.sorted {
            ascending ? $0.sessionStart < $1.sessionStart : $0.sessionStart > $1.sessionStart
        }

        // Limit
        if let limit { sorted = Array(sorted.prefix(limit)) }

        return sorted
    }
}

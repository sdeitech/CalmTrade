//
//  StepsHistoryStore.swift
//  CalmTrade
//
//  Reads raw step samples from CTMetricsRepository (no merging).
//

import Foundation

struct StepLogEntry: Identifiable, Equatable, Hashable {
    /// Stable ID so SwiftUI diffing stays cheap across reloads.
    /// Second-resolution timestamp + source + steps is enough for a diagnostic log.
    let id: String
    let timestamp: Date
    let steps: Int
    let source: CTMetricSource

    init(timestamp: Date, steps: Int, source: CTMetricSource) {
        self.timestamp = timestamp
        self.steps = steps
        self.source = source
        let sec = Int(timestamp.timeIntervalSince1970)
        self.id = "\(sec)|\(source.rawValue)|\(steps)"
    }
}

final class StepsHistoryStore {
    static let shared = StepsHistoryStore()
    private let repo = CTMetricsRepository.shared
    private init() {}

    /// Fetch raw step samples across sources (Polar 360, Apple Health, H10 if present).
    /// - Parameters:
    ///   - limit: max number of rows to return after sorting (nil = all in window)
    ///   - before: upper bound (default = now)
    ///   - ascending: true = oldest→newest, false = newest→oldest
    ///   - daysBack: how far to look back (default 14 days)
    func fetchAllSteps(limit: Int? = nil,
                       before: Date = Date(),
                       ascending: Bool = false,
                       daysBack: Int = 14) -> [StepLogEntry] {

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -abs(daysBack), to: before)
            ?? before.addingTimeInterval(-14 * 86400)

        var rows: [StepLogEntry] = []
        rows.reserveCapacity(1024)

        // Keep provenance per sample
        let sources: [CTMetricSource?] = [.polar360, .appleHealth, .polarH10]

        for src in sources {
            let xs: [CTMetricsRepository.CTBiometricPoint] =
                repo.series(kind: .steps, from: start, to: before, source: src)

            // Filter zeros so we show only actual data
            rows.append(contentsOf: xs.compactMap { s in
                let v = Int(s.value.rounded())
                guard v > 0 else { return nil }
                return StepLogEntry(
                    timestamp: s.date,
                    steps: v,
                    source: s.source
                )
            })
        }

        rows.sort {
            ascending ? ($0.timestamp < $1.timestamp) : ($0.timestamp > $1.timestamp)
        }

        if let limit, rows.count > limit {
            rows = Array(rows.prefix(limit))
        }
        return rows
    }
}

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

        // Unified segments (ct360 > HK)
        let segs = SleepRepository.shared.unifiedSegments(from: startDate, to: endDate)

        // Build session logs
        let logs = Self.buildLog(from: segs)

        // Sort
        var sorted = logs.sorted {
            ascending ? $0.sessionStart < $1.sessionStart : $0.sessionStart > $1.sessionStart
        }

        // Limit
        if let limit { sorted = Array(sorted.prefix(limit)) }

        return sorted
    }

    // MARK: - Log Shaping
    private static func buildLog(from segs: [SleepSegment]) -> [SleepLogEntry] {
        guard !segs.isEmpty else { return [] }

        let sorted = segs.sorted { $0.start < $1.start }
        let sessionGap: TimeInterval = 90 * 60

        // Group into sessions (merge if ≤90 min gap)
        var sessions: [[SleepSegment]] = []

        for s in sorted {
            if var last = sessions.last,
               let tail = last.last,
               s.start.timeIntervalSince(tail.end) <= sessionGap {

                last.append(s)
                sessions[sessions.count - 1] = last
            } else {
                sessions.append([s])
            }
        }

        // Convert sessions → SleepLogEntry
        var out: [SleepLogEntry] = []
        out.reserveCapacity(sessions.count)

        for group in sessions {
            guard let first = group.first, let last = group.last else { continue }

            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var deep: TimeInterval = 0
            var awake: TimeInterval = 0

            for seg in group {
                let dur = max(0, seg.end.timeIntervalSince(seg.start))
                switch seg.stage {
                case .rem:   rem  += dur
                case .core:  core += dur
                case .deep:  deep += dur
                case .awake: awake += dur
                }
            }

            let totalAsleep = totalAsleepUnionSeconds(from: group)

            // Calculate total including awake time (REM + Core + Deep + Awake)
            let totalWithAwake = rem + core + deep + awake

            // unified segments have mixed sources (ct360/HK)
            // pick highest priority source for the night:
            // ct360 > HK
            let source: SleepDataSource = {
                if group.contains(where: { $0.source == .ct360 }) { return .ct360 }
                if group.contains(where: { $0.source == .appleHealth }) { return .appleHealth }
                return group.first?.source ?? .appleHealth
            }()

            out.append(
                SleepLogEntry(
                    sessionStart: first.start,
                    sessionEnd: last.end,
                    totalSeconds: totalWithAwake,
                    remSeconds: rem,
                    coreSeconds: core,
                    deepSeconds: deep,
                    awakeSeconds: awake,
                    source: source
                )
            )
        }

        // newest first by default (sorting done in caller)
        return out
    }

    // MARK: - Union-of-asleep-only
    private static func totalAsleepUnionSeconds(from segs: [SleepSegment]) -> TimeInterval {
        var intervals = segs
            .filter { $0.stage != .awake }
            .map { ($0.start, $0.end) }
            .sorted { $0.0 < $1.0 }

        var merged: [(Date, Date)] = []

        for (s, e) in intervals {
            guard s < e else { continue }
            if let last = merged.last, s <= last.1 {
                merged[merged.count - 1].1 = max(last.1, e)
            } else {
                merged.append((s, e))
            }
        }

        return merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
    }
}

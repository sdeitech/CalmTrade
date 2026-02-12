//
//  StepEngine.swift
//  CalmTrade
//
//  Unified minute-level steps with source priority (Polar360 > Apple Health).
//  Includes a tiny thread-safe cache + invalidateCache().
//

import Foundation

enum StepEngine {
    // MARK: - Dependencies
    private static let repo = CTMetricsRepository.shared
    private static let priority: [CTMetricSource] = [.polar360, .appleHealth]

    // MARK: - Cache
    // Cache by [start,end) minute window (second precision is fine here).
    private struct CacheKey: Hashable {
        let startSec: Int
        let endSec: Int
    }
    private static var cache: [CacheKey: [(Date, Int)]] = [:]
    private static let cacheQueue = DispatchQueue(label: "StepEngine.cache", attributes: .concurrent)

    /// External callers (e.g., Biometrics VM) can ping this after a repo upsert.
    static func invalidateCache() {
        cacheQueue.async(flags: .barrier) { cache.removeAll() }
    }

    private static func minuteKey(_ ts: Date) -> Date {
        let c = Calendar.current
        return c.date(bySetting: .second, value: 0, of: ts) ?? ts
    }

    // MARK: - Public API

    /// Raw minute series (merged, priority applied, zeroes dropped). Cached per window.
    static func seriesPerMinute(from start: Date, to end: Date) -> [(Date, Int)] {
        let key = CacheKey(startSec: Int(start.timeIntervalSince1970),
                           endSec: Int(end.timeIntervalSince1970))

        // Fast path: cached
        if let cached = cacheQueue.sync(execute: { cache[key] }) {
            return cached
        }

        debugPrint("=== StepEngine Debug ===")
        debugPrint("Fetching steps data from \(start) to \(end)")

        // Pull per-source raw points (detached value structs)
        let polar = repo.series(kind: .steps, from: start, to: end, source: .polar360)
        let apple = repo.series(kind: .steps, from: start, to: end, source: .appleHealth)

        debugPrint("Polar360 steps data count: \(polar.count)")
        debugPrint("Apple Health steps data count: \(apple.count)")

        // Aggregate to minute buckets per source
        func aggregate(_ xs: [CTMetricsRepository.CTBiometricPoint]) -> [(Date, Int)] {
            var m: [Date: Int] = [:]
            m.reserveCapacity(xs.count)
            for s in xs {
                let k = minuteKey(s.date)
                let v = Int(s.value.rounded())
                if v > 0 { m[k, default: 0] += v }
            }
            return m.map { ($0.key, $0.value) }
        }

        let aPolar = aggregate(polar)
        let aApple = aggregate(apple)

        debugPrint("Aggregated Polar360 minutes: \(aPolar.count)")
        debugPrint("Aggregated Apple Health minutes: \(aApple.count)")

        // Merge with priority (fold lower priority first, overwrite with higher)
        var merged: [Date: (CTMetricSource, Int)] = [:]
        func fold(_ xs: [(Date, Int)], src: CTMetricSource) {
            for (ts, v) in xs {
                if let cur = merged[ts] {
                    let keepCur = priority.firstIndex(of: cur.0)! <= priority.firstIndex(of: src)!
                    if !keepCur { merged[ts] = (src, v) }
                } else {
                    merged[ts] = (src, v)
                }
            }
        }

        fold(aApple, src: .appleHealth)
        fold(aPolar, src: .polar360)

        debugPrint("After merging with priority (Polar360 > Apple Health): \(merged.count) unique time slots")

        // Count how many slots came from each source
        let polarCount = merged.values.filter { $0.0 == .polar360 }.count
        let appleCount = merged.values.filter { $0.0 == .appleHealth }.count
        debugPrint("Final merged data - Polar360: \(polarCount) minutes, Apple Health: \(appleCount) minutes")

        let result = merged.keys.sorted().map { ($0, merged[$0]!.1) }

        debugPrint("Final result: \(result.count) minute entries")
        debugPrint("======================")

        // Store in cache
        cacheQueue.async(flags: .barrier) { cache[key] = result }
        return result
    }

    /// Sum of steps in [start, end).
    static func stepsTotal(from start: Date, to end: Date) -> Double {
        Double(seriesPerMinute(from: start, to: end).reduce(0) { $0 + $1.1 })
    }
}

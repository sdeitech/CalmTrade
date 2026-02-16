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

        // Pull per-source raw points (detached value structs)
        let polar = repo.series(kind: .steps, from: start, to: end, source: .polar360)
        let apple = repo.series(kind: .steps, from: start, to: end, source: .appleHealth)

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

        let aPolar = aggregate(polar).sorted { $0.0 < $1.0 }
        let aApple = aggregate(apple).sorted { $0.0 < $1.0 }

        // Strict source policy:
        // - Polar connected -> Polar only
        // - Polar disconnected -> Apple only
        let isPolarConnected: Bool = {
            if case .connected = PolarManager.shared.connectionState { return true }
            return false
        }()

        let result = isPolarConnected ? aPolar : aApple

        // Store in cache
        cacheQueue.async(flags: .barrier) { cache[key] = result }
        return result
    }

    /// Sum of steps in [start, end).
    static func stepsTotal(from start: Date, to end: Date) -> Double {
        Double(seriesPerMinute(from: start, to: end).reduce(0) { $0 + $1.1 })
    }
}

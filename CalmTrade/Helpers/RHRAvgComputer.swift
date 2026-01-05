//
//  RHRAvgComputer.swift
//  CalmTrade
//
//  Created by Anas Parekh on 10/10/25.
//


import Foundation

/// Minimal inputs from your nightly Polar 360 sync.
// MARK: - P360SleepPacket (Codable + closure-compatible)

public struct P360SleepPacket: Codable {
    // MARK: Nested models
    public struct HR: Codable {
        public let ts: Date
        public let bpm: Double
    }

    public enum Stage: String, Codable { case awake, rem, light, deep, unknown }
    public enum Quality: String, Codable { case good, fair, poor }

    public struct Segment: Codable {
        public let start: Date
        public let end: Date
        public let stage: Stage
    }

    public struct Motion: Codable {
        public let start: Date
        public let end: Date
        public let still: Bool
    }

    /// Backing data that makes `ppgQuality(_:_:)` possible without storing a function.
    public struct QualityWindow: Codable {
        public let start: Date
        public let end: Date
        public let quality: Quality
    }

    // MARK: Payload
    public let hrSeries: [HR]
    public let stages: [Segment]
    public let motions: [Motion]
    public let sleepEnd: Date

    /// Windows of PPG signal quality for the night.
    /// Server should return these; if not available, you can fill with a single `.fair` window for the whole night.
    public let qualityWindows: [QualityWindow]

    // MARK: Derived API (keeps your call-site the same)
    /// Returns dominant PPG quality for the given interval based on overlapping quality windows.
    public func ppgQuality(_ start: Date, _ end: Date) -> Quality {
        let overlapping = qualityWindows.filter { $0.end > start && $0.start < end }
        guard !overlapping.isEmpty else { return .fair } // neutral default
        // Weight by overlap duration (better than simple counts)
        var weights: [Quality: TimeInterval] = [:]
        for w in overlapping {
            let s = max(start, w.start)
            let e = min(end,   w.end)
            let dur = e.timeIntervalSince(s)
            if dur > 0 { weights[w.quality, default: 0] += dur }
        }
        return weights.max(by: { $0.value < $1.value })?.key ?? .fair
    }

    // Optional: map snake_case if your backend uses it
    // private enum CodingKeys: String, CodingKey {
    //     case hrSeries = "hr_series"
    //     case stages, motions, sleepEnd = "sleep_end", qualityWindows = "quality_windows"
    // }
}


/// Output you asked for.
public struct RHRAvgResult {
    public let valueBpm: Double?
    public let source: CTMetricSource   // .appleHealth / .polar360 / (fallback via .appleHealth if unknown)
    public let timestamp: Date          // when we computed/saved it
    public let qualityFlag: String      // "good" | "fair" | "poor" | "unknown"
}

public enum RHRAvgComputer {
    /// Main entry
    public static func compute(
        hkRhr: (value: Double, date: Date)?,
        hkAgeHours: Double?,
        packet: P360SleepPacket?,
        previousRhr: Double? = nil
    ) -> RHRAvgResult {
        // 1) HealthKit if present and fresh (<36h)
        if let hk = hkRhr, let age = hkAgeHours, age < 36 {
            return .init(valueBpm: hk.value,
                         source: .appleHealth,
                         timestamp: Date(),
                         qualityFlag: "good")
        }

        // 2) Derive from Polar 360 last-night sleep
        guard let pkt = packet,
              let rhr360 = computeFromPolar360(pkt) else {
            // 3) Unknown
            return .init(valueBpm: nil,
                         source: .appleHealth, // keep source neutral for "unknown"
                         timestamp: Date(),
                         qualityFlag: "unknown")
        }

        var rhr = rhr360.value
        // 5) Optional smoothing
        if let prev = previousRhr { rhr = 0.7 * rhr + 0.3 * prev }

        // 6) Disagreement guard
        if let hk = hkRhr {
            let delta = abs(hk.value - rhr)
            let preferHK = (delta > 8) && (rhr360.quality != "good")
            if preferHK {
                return .init(valueBpm: hk.value,
                             source: .appleHealth,
                             timestamp: Date(),
                             qualityFlag: "good")
            }
        }

        return .init(valueBpm: rhr,
                     source: .polar360,
                     timestamp: pkt.sleepEnd,
                     qualityFlag: rhr360.quality)
    }

    // MARK: - Helpers

    private struct Window { let start: Date; let end: Date; let mean: Double; let q: String }

    /// Implements steps 1–4 from your spec.
    private static func computeFromPolar360(_ p: P360SleepPacket) -> (value: Double, quality: String)? {
        // 1) Restful segments → prefer NREM (Light+Deep); else stillness
        let nrem = p.stages
            .filter { $0.stage == .light || $0.stage == .deep }
            .map { ($0.start, $0.end) }

        let restful: [(Date, Date)]
        if !nrem.isEmpty {
            restful = nrem
        } else {
            restful = p.motions.filter { $0.still }.map { ($0.start, $0.end) }
        }

        guard !restful.isEmpty else { return nil }

        // Index HR by time
        let hr = p.hrSeries.sorted { $0.ts < $1.ts }

        // 2) 5-min rolling mean, 1-min step, within restful bounds
        var windows: [Window] = []
        for (rStart, rEnd) in restful {
            var cursor = alignDown(rStart, stepSec: 60)
            while cursor.addingTimeInterval(300) <= rEnd {
                let wStart = cursor
                let wEnd   = cursor.addingTimeInterval(300)
                let samples = hrInRange(hr, wStart, wEnd)
                if samples.count >= 30 { // ~6s cadence typical, be lenient
                    let mean = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
                    let q = mapQuality(p.ppgQuality(wStart, wEnd))
                    if q != "poor" { windows.append(Window(start: wStart, end: wEnd, mean: mean, q: q)) }
                }
                cursor = cursor.addingTimeInterval(60)
            }
        }
        guard !windows.isEmpty else { return nil }

        // 3) Trim to 10th–90th percentile of window means (robustness)
        let means = windows.map(\.mean).sorted()
        let lo = percentile(means, 0.10)
        let hi = percentile(means, 0.90)
        let trimmed = windows.filter { $0.mean >= lo && $0.mean <= hi }
        guard !trimmed.isEmpty else { return nil }

        // 4) Lowest 30 consecutive minutes (6 windows @ 1-min stride)
        var best: (value: Double, quality: String)? = nil
        if trimmed.count >= 6 {
            for i in 0...(trimmed.count - 6) {
                let slice = Array(trimmed[i..<i+6])
                // ensure consecutive, no big gaps
                let consec = zip(slice, slice.dropFirst()).allSatisfy { $0.end == $1.start }
                if !consec { continue }
                let m = slice.map(\.mean).reduce(0, +) / 6.0
                let q = dominantQuality(slice.map(\.q))
                if best == nil || m < best!.value { best = (m, q) }
            }
        }
        return best
    }

    // Utilities
    private static func hrInRange(_ hr: [P360SleepPacket.HR], _ s: Date, _ e: Date) -> [P360SleepPacket.HR] {
        hr.filter { $0.ts >= s && $0.ts < e }
    }
    private static func alignDown(_ t: Date, stepSec: TimeInterval) -> Date {
        let x = floor(t.timeIntervalSince1970 / stepSec) * stepSec
        return Date(timeIntervalSince1970: x)
    }
    private static func percentile(_ x: [Double], _ p: Double) -> Double {
        if x.isEmpty { return .nan }
        let pos = Double(x.count - 1) * p
        let lo = Int(floor(pos)), hi = Int(ceil(pos))
        if lo == hi { return x[lo] }
        let w = pos - Double(lo)
        return x[lo] * (1 - w) + x[hi] * w
    }
    private static func mapQuality(_ q: P360SleepPacket.Quality) -> String {
        switch q { case .good: return "good"; case .fair: return "fair"; case .poor: return "poor" }
    }
    private static func dominantQuality(_ qs: [String]) -> String {
        // simple: if any "fair" and none "poor" → "fair"; if any "poor" → "fair" was filtered upstream
        return qs.contains("fair") ? "fair" : "good"
    }
}

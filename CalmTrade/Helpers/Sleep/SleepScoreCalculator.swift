//
//  SleepScoreCalculator.swift
//  CalmTrade
//

import Foundation

struct SleepScoreComponent {
    let score: Int
    let maxScore: Int
}

struct SleepScoreBreakdown {
    let totalScore: Int

    let sleepAmount: SleepScoreComponent
    let sleepSolidity: SleepScoreComponent
    let sleepRegeneration: SleepScoreComponent

    let interruptionsScore: Int
    let continuityScore: Int
    let sleepEfficiencyScore: Int

    let remScore: Int
    let deepScore: Int
    let coreScore: Int

    let sleepTimeMinutes: Int
    let wakeMinutes: Int

    let remMinutes: Int
    let deepMinutes: Int
    let coreMinutes: Int
}

enum SleepScoreCalculator {

    static func calculate(
        segments: [SleepSegment],
        sleepGoalMinutes: Int = 480
    ) -> SleepScoreBreakdown? {
        let ordered = segments.sorted { $0.start < $1.start }
        guard !ordered.isEmpty else { return nil }

        let goal = max(1, sleepGoalMinutes)

        var wakeSeconds: TimeInterval = 0
        var coreSeconds: TimeInterval = 0
        var deepSeconds: TimeInterval = 0
        var remSeconds: TimeInterval = 0

        for seg in ordered {
            let duration = max(0, seg.end.timeIntervalSince(seg.start))
            switch seg.stage {
            case .awake: wakeSeconds += duration
            case .core: coreSeconds += duration
            case .deep: deepSeconds += duration
            case .rem: remSeconds += duration
            }
        }

        let totalSleepSeconds = coreSeconds + deepSeconds + remSeconds
        let sleepWindowSeconds = max(1.0, totalSleepSeconds + wakeSeconds)
        guard totalSleepSeconds > 0 else { return nil }

        let totalSleepMinutes = totalSleepSeconds / 60.0
        let wakeMinutes = wakeSeconds / 60.0
        let sleepEfficiency = totalSleepSeconds / sleepWindowSeconds

        // Amount (0...40): linear to goal.
        let amountRaw = 40.0 * (totalSleepMinutes / Double(goal))
        let amount = clamp(Int(amountRaw.rounded()), min: 0, max: 40)

        // Solidity (0...30): interruptions + continuity + efficiency.
        let wakeBoutCount = countWakeBouts(from: ordered, minDuration: 30)
        let interruptionsScore: Int = {
            if wakeBoutCount <= 2 { return 10 }
            if wakeBoutCount <= 4 { return 8 }
            if wakeBoutCount <= 6 { return 6 }
            if wakeBoutCount <= 8 { return 4 }
            return 2
        }()

        let continuityScore: Int = {
            if wakeMinutes <= 10 { return 10 }
            if wakeMinutes <= 20 { return 8 }
            if wakeMinutes <= 30 { return 6 }
            if wakeMinutes <= 45 { return 4 }
            return 2
        }()

        let sleepEfficiencyScore: Int = {
            if sleepEfficiency >= 0.95 { return 10 }
            if sleepEfficiency >= 0.90 { return 8 }
            if sleepEfficiency >= 0.85 { return 6 }
            if sleepEfficiency >= 0.80 { return 4 }
            return 2
        }()

        let solidity = interruptionsScore + continuityScore + sleepEfficiencyScore

        // Regeneration (0...30): REM + Deep + Core.
        let remPct = remSeconds / totalSleepSeconds
        let deepPct = deepSeconds / totalSleepSeconds
        let corePct = coreSeconds / totalSleepSeconds

        let remScore = remScore(for: remPct)
        let deepScore = deepScore(for: deepPct)
        let coreScore = coreScore(for: corePct)
        let regeneration = remScore + deepScore + coreScore

        let total = clamp(amount + solidity + regeneration, min: 0, max: 100)

        return SleepScoreBreakdown(
            totalScore: total,
            sleepAmount: SleepScoreComponent(score: amount, maxScore: 40),
            sleepSolidity: SleepScoreComponent(score: solidity, maxScore: 30),
            sleepRegeneration: SleepScoreComponent(score: regeneration, maxScore: 30),
            interruptionsScore: interruptionsScore,
            continuityScore: continuityScore,
            sleepEfficiencyScore: sleepEfficiencyScore,
            remScore: remScore,
            deepScore: deepScore,
            coreScore: coreScore,
            // UI "Sleep Time" should include awake slices (time in bed).
            sleepTimeMinutes: Int((sleepWindowSeconds / 60.0).rounded()),
            wakeMinutes: Int(wakeMinutes.rounded()),
            remMinutes: Int((remSeconds / 60.0).rounded()),
            deepMinutes: Int((deepSeconds / 60.0).rounded()),
            coreMinutes: Int((coreSeconds / 60.0).rounded())
        )
    }

    private static func countWakeBouts(from segments: [SleepSegment], minDuration: TimeInterval) -> Int {
        let wakeSegments = segments
            .filter { $0.stage == .awake }
            .sorted { $0.start < $1.start }

        guard !wakeSegments.isEmpty else { return 0 }

        // Merge wake slices that are essentially continuous.
        let mergeGap: TimeInterval = 30
        var merged: [(start: Date, end: Date)] = []

        for seg in wakeSegments {
            if let last = merged.last,
               seg.start.timeIntervalSince(last.end) <= mergeGap {
                merged[merged.count - 1].end = max(last.end, seg.end)
            } else {
                merged.append((seg.start, seg.end))
            }
        }

        return merged.filter { $0.end.timeIntervalSince($0.start) >= minDuration }.count
    }

    private static func remScore(for pct: Double) -> Int {
        if pct >= 0.20 && pct <= 0.25 { return 12 }
        if (pct >= 0.17 && pct < 0.20) || (pct > 0.25 && pct <= 0.28) { return 10 }
        if (pct >= 0.14 && pct < 0.17) || (pct > 0.28 && pct <= 0.31) { return 8 }
        if (pct >= 0.10 && pct < 0.14) || (pct > 0.31 && pct <= 0.35) { return 6 }
        return 4
    }

    private static func deepScore(for pct: Double) -> Int {
        if pct >= 0.15 && pct <= 0.25 { return 12 }
        if (pct >= 0.12 && pct < 0.15) || (pct > 0.25 && pct <= 0.28) { return 10 }
        if (pct >= 0.09 && pct < 0.12) || (pct > 0.28 && pct <= 0.32) { return 8 }
        if (pct >= 0.06 && pct < 0.09) || (pct > 0.32 && pct <= 0.36) { return 6 }
        return 4
    }

    private static func coreScore(for pct: Double) -> Int {
        if pct >= 0.45 && pct <= 0.65 { return 6 }
        if (pct >= 0.40 && pct < 0.45) || (pct > 0.65 && pct <= 0.70) { return 5 }
        if (pct >= 0.35 && pct < 0.40) || (pct > 0.70 && pct <= 0.75) { return 4 }
        if (pct >= 0.30 && pct < 0.35) || (pct > 0.75 && pct <= 0.80) { return 3 }
        return 2
    }

    private static func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}

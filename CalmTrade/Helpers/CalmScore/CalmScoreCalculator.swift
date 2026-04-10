//
//  CalmScoreCalculator.swift
//  CalmTrade
//
//  Pure Physiological Readiness Calculator (v3.0.0)
//  - Removes EmotionInputs entirely
//  - Removes Edge completely
//  - Removes phase mixing logic
//  - CalmScore = readiness (0–100)
//  - Baseline-aware (HRV log-space, HR/RHR/Sleep linear)
//

import Foundation

// MARK: - Models

/// Biometric inputs (any may be nil if unavailable)
public struct CalmScoreBiometricInputs: Codable {
    public let heartRate: Double?            // bpm
    public let hrvInRmssd: Double?           // ms
    public let hrvInSdnn: Double?            // ms
    public let restingHeartRate: Double?     // bpm
    public let sleepDurationInHours: Double? // hours

    public init(heartRate: Double? = nil,
                hrvInRmssd: Double? = nil,
                hrvInSdnn: Double? = nil,
                restingHeartRate: Double? = nil,
                sleepDurationInHours: Double? = nil) {
        self.heartRate = heartRate
        self.hrvInRmssd = hrvInRmssd
        self.hrvInSdnn = hrvInSdnn
        self.restingHeartRate = restingHeartRate
        self.sleepDurationInHours = sleepDurationInHours
    }
}

/// Kept for API compatibility (optional to use)
public enum CalmScorePhase: String, Codable {
    case pre, during, post
}

/// Output payload (Edge removed — kept only as “mirrored readiness” for backward structures)
public struct CalmScoreSession: Codable {
    public let version: String
    public let timestampUtc: String
    public let phase: CalmScorePhase
    public let readiness: Double
    public let calmScore: Double
    public let coveragePct: Double
}

// MARK: - Baselines

public struct LogBaseline: Codable {
    public let meanLog: Double
    public let sdLog: Double
}

public struct LinearBaseline: Codable {
    public let mean: Double
    public let sd: Double
}

public struct Baselines: Codable {
    public let rmssd: LogBaseline?
    public let sdnn: LogBaseline?
    public let hr: LinearBaseline?
    public let rhr: LinearBaseline?
    public let sleep: LinearBaseline?
}

// Cohort defaults (fallback)
let defaultRmssd = LogBaseline(meanLog: log(45.0), sdLog: 0.35)
let defaultSdnn  = LogBaseline(meanLog: log(50.0), sdLog: 0.40)
let defaultHR    = LinearBaseline(mean: 70.0, sd: 15.0)
let defaultRHR   = LinearBaseline(mean: 60.0, sd: 8.0)
let defaultSleep = LinearBaseline(mean: 7.5, sd: 1.0)

// MARK: - Calculator

public final class CalmScoreCalculator {

    public struct Tunables {
        static let slope: Double = 1.1
        static let bias: Double  = 0.10

        static let wHRV: Double = 0.8//0.55
        static let wHR: Double  = 0.5//0.25
        static let wRHR: Double = 0.3//0.15
        static let wSleep: Double = 0.4//0.20

        static let wRmssd: Double = 0.6
        static let wSdnn: Double  = 0.4
        static let divergenceLambda: Double = 0.25
    }

    // MARK: - Pure physiological readiness (0–100)
    public func calculate(from bio: CalmScoreBiometricInputs,
                          baselines bl: Baselines? = nil) -> Double {

        let base = bl ?? Baselines(
            rmssd: defaultRmssd,
            sdnn:  defaultSdnn,
            hr:    defaultHR,
            rhr:   defaultRHR,
            sleep: defaultSleep
        )

        // HRV Z
        let zRmssd = zLog(value: bio.hrvInRmssd, baseline: base.rmssd ?? defaultRmssd)
        let zSdnn  = zLog(value: bio.hrvInSdnn,  baseline: base.sdnn  ?? defaultSdnn)

        var zHRV: Double?
        if let zr = zRmssd, let zs = zSdnn {
            let combined = (Tunables.wRmssd * zr + Tunables.wSdnn * zs) /
                           (Tunables.wRmssd + Tunables.wSdnn)
            let penalty  = Tunables.divergenceLambda * abs(zr - zs)
            zHRV = combined - penalty
        } else {
            zHRV = zRmssd ?? zSdnn
        }

        // Linear Z (HR and RHR inverted)
        let zHR  = zLinear(value: bio.heartRate, baseline: base.hr ?? defaultHR)?.neg()
        let zRHR = zLinear(value: bio.restingHeartRate, baseline: base.rhr ?? defaultRHR)?.neg()
        let zSlp = zLinear(value: bio.sleepDurationInHours, baseline: base.sleep ?? defaultSleep)

        // Combine weighted Z-scores
        var wSum = 0.0, zSum = 0.0

        func add(_ z: Double?, _ w: Double) {
            if let z { zSum += z * w; wSum += w }
        }

        add(zHRV, Tunables.wHRV)
        add(zHR, Tunables.wHR)
        add(zRHR, Tunables.wRHR)
//        add(zSlp, Tunables.wSleep)

        let scoreZ = (wSum > 0 ? zSum / wSum : 0)

        // Sigmoid → 0–100
        let norm = sigmoid(Tunables.slope * scoreZ + Tunables.bias)
        return clamp01(norm) * 100.0
    }

    // MARK: - Backward-compatible session result
    public func session(from bio: CalmScoreBiometricInputs,
                        phase: CalmScorePhase = .during,
                        baselines: Baselines? = nil) -> CalmScoreSession {

        let readiness = calculate(from: bio, baselines: baselines)

        // Coverage %
        let available = [
            bio.hrvInRmssd,
            bio.hrvInSdnn,
            bio.heartRate,
            bio.restingHeartRate,
            bio.sleepDurationInHours
        ].compactMap { $0 }.count

        let coverage = (Double(available) / 5.0) * 100.0

        return CalmScoreSession(
            version: "2.1.0",
            timestampUtc: ISO8601DateFormatter().string(from: Date()),
            phase: phase,
            readiness: readiness,
            calmScore: readiness,
            coveragePct: coverage
        )
    }

    // MARK: - Helpers

    func zLog(value: Double?, baseline: LogBaseline) -> Double? {
        guard let x = value, x > 0, baseline.sdLog > 0 else { return nil }
        return clamp(-3, 3, (log(x) - baseline.meanLog) / baseline.sdLog)
    }

    func zLinear(value: Double?, baseline: LinearBaseline) -> Double? {
        guard let x = value, baseline.sd > 0 else { return nil }
        return clamp(-3, 3, (x - baseline.mean) / baseline.sd)
    }

    func sigmoid(_ x: Double) -> Double { 1 / (1 + exp(-x)) }

    private func clamp(_ lo: Double, _ hi: Double, _ x: Double) -> Double { min(hi, max(lo, x)) }
    func clamp01(_ x: Double) -> Double { clamp(0, 1, x) }
}

extension Double { func neg() -> Double { -self } }

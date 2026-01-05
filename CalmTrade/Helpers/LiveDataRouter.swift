//
//  LiveDataRouter.swift
//  CalmTrade
//
//  Unified live pipeline for Polar H10 (RR) and Polar 360/optical (PPI-as-RR).
//  Now user-aware (per-user metrics repository).
//

import Foundation

final class LiveDataRouter {
    static let shared = LiveDataRouter()
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserChanged),
            name: .userAccountDidChange,
            object: nil
        )
    }

    // MARK: - Source labeling
    private enum SourceLabel {
        case polarH10, polar360, hkSnapshot
        var ctMetricSource: CTMetricSource {
            switch self {
            case .polarH10: return .polarH10
            case .polar360: return .polar360
            case .hkSnapshot: return .appleHealth
            }
        }
    }

    private func currentLabel() -> SourceLabel {
        switch DeviceManager.shared.currentSource {
        case .polarH10:       return .polarH10
        case .polar360:       return .polar360
        case .appleHealthKit: return .hkSnapshot
        }
    }

    // MARK: - Buffers & state
    private struct RRPoint { let ms: Int; let ts: Date }
    private var rrBuffer: [RRPoint] = []
    private var lnEMA: Double?               // smoothed ln(RMSSD)
    private let alpha: Double = 0.12
    private let maxStepLn: Double = 0.10

    private let windowSec: TimeInterval = 300
    private let windowSecSDNN: TimeInterval = 300
    private let windowSecRMSSD: TimeInterval = 200
    private let tickSec: TimeInterval = 10
    private var lastTickAt: Date?
    private let softGapResetSec: TimeInterval = 20

    private let warmupBeatsMin: Int = 100

    private func baseMinBeatsTarget(for label: SourceLabel) -> Int {
        switch label {
        case .polar360:   return 180
        case .polarH10:   return 200
        case .hkSnapshot: return 200
        }
    }

    private func minBeatsTargetScaled(for label: SourceLabel, windowSec: TimeInterval) -> Int {
        Int(ceil(Double(baseMinBeatsTarget(for: label)) * (windowSec / 300.0)))
    }

    private func warmupBeatsMinScaled(windowSec: TimeInterval) -> Int {
        Int(ceil(Double(warmupBeatsMin) * (windowSec / 300.0)))
    }

    // MARK: - Public wiring
    func attachToPolar(_ pm: PolarManager = .shared) {
        // Observe connection changes
        _ = pm.addConnectionObserver { [weak self] state in
            guard let self else { return }
            switch state {
            case .connected, .connecting, .disconnected:
                self.reset()
            }
        }

        pm.onHeartRate = { bpm, ts in
            let label = self.currentLabel()
            guard label != .hkSnapshot else { return }

            let src = label.ctMetricSource
            SocketClient.shared.send(key: "save_biometric", payload: [
                "biometricType": "heartRate",
                "biometricValue": bpm,
                "unit": "bpm",
                "sourceDevice": src.rawValue
            ])

            // Store per-user
            CTMetricsRepository.shared.save(kind: .heartRate,
                                            value: bpm,
                                            unit: "bpm",
                                            source: src,
                                            date: ts)
            NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
        }

        pm.onRRIntervals = { rrMsBatch, batchTs in
            let label = self.currentLabel()
            guard label != .hkSnapshot else { return }
            self.handleRRBatch(rrMsBatch, ts: batchTs, label: label)
        }
    }

    private func reset() {
        rrBuffer.removeAll()
        lnEMA = nil
        lastTickAt = nil
    }

    @objc private func onUserChanged() {
        reset()
    }

    // MARK: - Core pipeline
    private func handleRRBatch(_ rrMsBatch: [Int], ts: Date, label: SourceLabel) {
        guard !rrMsBatch.isEmpty else { return }

        if let last = rrBuffer.last, ts.timeIntervalSince(last.ts) > softGapResetSec {
            lastTickAt = nil
        }

        let cleaned = clean(rrMsBatch, label: label)
        guard !cleaned.isEmpty else { return }

        rrBuffer.append(contentsOf: cleaned.map { RRPoint(ms: $0, ts: ts) })

        // Trim buffer
        rrBuffer.removeAll { $0.ts < ts.addingTimeInterval(-windowSecSDNN) }

        if let lastT = lastTickAt, ts.timeIntervalSince(lastT) < tickSec { return }
        lastTickAt = ts

        let rr300 = rrBuffer.filter { $0.ts >= ts.addingTimeInterval(-windowSecSDNN) }.map { $0.ms }
        let rr200 = rrBuffer.filter { $0.ts >= ts.addingTimeInterval(-windowSecRMSSD) }.map { $0.ms }

        var sdnnComputed: Double?
        var rmssdSmoothed: Double?

        // RMSSD
        if rr200.count >= minBeatsTargetScaled(for: label, windowSec: windowSecRMSSD) {
            let rmssdRaw = computeRMSSD(rr200)
            if rmssdRaw.isFinite, rmssdRaw > 0 {
                let ln = log(rmssdRaw)
                let next = (lnEMA == nil) ? ln : (alpha * ln + (1 - alpha) * lnEMA!)
                let limited = (lnEMA == nil) ? next : max(min(next, lnEMA! + maxStepLn), lnEMA! - maxStepLn)
                lnEMA = limited
                rmssdSmoothed = exp(limited)

                let src = label.ctMetricSource
                CTMetricsRepository.shared.save(kind: .rmssd,
                                                value: rmssdSmoothed!,
                                                unit: "ms",
                                                source: src,
                                                date: ts)
                NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
            }
        }

        // SDNN
        if rr300.count >= minBeatsTargetScaled(for: label, windowSec: windowSecSDNN) {
            let sdnn = computeSDNN(rr300)
            if sdnn.isFinite, sdnn > 0 {
                sdnnComputed = sdnn
                let src = label.ctMetricSource
                CTMetricsRepository.shared.save(kind: .sdnn,
                                                value: sdnn,
                                                unit: "ms",
                                                source: src,
                                                date: ts)
                NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
            }
        }

        if let r = rmssdSmoothed, let s = sdnnComputed {
            DeviceManager.shared.updateLiveRMSSD(r, s)
        }
    }

    // MARK: - Artifact cleaner
    private func clean(_ rrMs: [Int], label: SourceLabel) -> [Int] {
        guard !rrMs.isEmpty else { return [] }
        let bounded = rrMs.filter { $0 >= 300 && $0 <= 2000 }
        guard !bounded.isEmpty else { return [] }

        var accepted: [Int] = []
        let backTail = rrBuffer.suffix(5).map { $0.ms }

        for rr in bounded {
            let neighborhood = Array((backTail + accepted).suffix(5))
            guard !neighborhood.isEmpty else {
                accepted.append(rr); continue
            }
            let med = median(neighborhood)

            let (minAbs, relFrac): (Double, Double) = {
                switch label {
                case .polar360: return (180.0, 0.30)
                case .polarH10, .hkSnapshot: return (150.0, 0.20)
                }
            }()

            let gateAbs = max(minAbs, relFrac * med)
            if abs(Double(rr) - med) <= gateAbs { accepted.append(rr) }
        }
        return accepted
    }

    // MARK: - RMSSD / SDNN
    private func computeRMSSD(_ rr: [Int]) -> Double {
        guard rr.count >= 2 else { return 0 }
        var sumSq: Double = 0
        var prev = rr[0]
        for i in 1..<rr.count {
            let d = Double(rr[i] - prev)
            sumSq += d*d
            prev = rr[i]
        }
        return sqrt(sumSq / Double(rr.count - 1))
    }

    private func computeSDNN(_ rr: [Int]) -> Double {
        guard rr.count >= 2 else { return 0 }
        let mean = rr.reduce(0.0) { $0 + Double($1) } / Double(rr.count)
        let sumSq = rr.reduce(0.0) { $0 + pow(Double($1) - mean, 2.0) }
        return sqrt(sumSq / Double(rr.count - 1))
    }

    private func median(_ xs: [Int]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let sorted = xs.sorted()
        let c = sorted.count
        return (c % 2 == 1)
            ? Double(sorted[c/2])
            : 0.5 * Double(sorted[c/2 - 1] + sorted[c/2])
    }
}

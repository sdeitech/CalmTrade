//
//  PolarManager+Metrics.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/09/25.
//

import Foundation
import PolarBleSdk
import os.log

// MARK: - Metrics (RHR / Sleep / Daily Activity)

extension PolarManager {

    // MARK: - Resting HR (RHR) computation

    func computeRestingHeartRate(from rrsMs: [Int], source: CTMetricSource, deviceId: String) {
        guard !rrsMs.isEmpty else { return }

        // Convert RR → instantaneous HR (bpm) → median
        let bpmValues: [Double] = rrsMs.map { 60000.0 / Double($0) }
        let sorted = bpmValues.sorted()
        let median: Double = sorted[sorted.count / 2]

        NSLog("[PM][RHR] computed RHR median \(median) bpm from \(rrsMs.count) RR samples")

        onRHRComputed?(median, source, deviceId)

        // Optional: persist to CTMetricsRepository
        _ = CTMetricsRepository.shared.upsert(kind: .restingHeartRate,
                                              value: median,
                                              unit: "bpm",
                                              source: source,
                                              date: Date())
    }

    // MARK: - Sleep metrics (Polar SDK 6.7)

    func processPolarSleep(_ sleep: PolarSleepData.PolarSleepAnalysisResult, for deviceId: String) {
        NSLog("[PM][Sleep] received PolarSleepData for \(deviceId)")

        guard let start = sleep.sleepStartTime,
              let end = sleep.sleepEndTime,
              let phases = sleep.sleepWakePhases,
              !phases.isEmpty else {
            NSLog("[PM][Sleep] missing or empty sleep phases for \(deviceId)")
            return
        }

        // Build absolute start/end times for each phase
        var segments: [CTSleepSegment] = []
        for phase in phases {
            let segStart = start.addingTimeInterval(TimeInterval(phase.secondsFromSleepStart))
            // Determine segment duration: next phase’s start or final end
            let nextIndex = phases.firstIndex(where: { $0.secondsFromSleepStart > phase.secondsFromSleepStart })
            let segEnd: Date
            if let nextIdx = nextIndex, nextIdx < phases.count {
                segEnd = start.addingTimeInterval(TimeInterval(phases[nextIdx].secondsFromSleepStart))
            } else {
                segEnd = end
            }

            let stage: CTSleepStage
            switch phase.state {
            case .WAKE: stage = .awake
            case .REM:  stage = .rem
            case .NONREM12: stage = .light
            case .NONREM3:  stage = .deep
            case .UNKNOWN:  stage = .light
            case .none:
                stage = .awake
            }

            segments.append(CTSleepSegment(start: segStart, end: segEnd, stage: stage))
        }

        let episode = CTSleepEpisode(
            date: end, // CalmTrade convention: episode.date = sleep end date
            source: .polar360,
            segments: segments,
            qualityFlag: sleep.userSleepRating?.rawValue.description
        )

        NSLog("[PM][Sleep] built episode start=\(start) end=\(end) totalSegments=\(segments.count)")

        CTMetricsRepository.shared.upsertSleepEpisode(episode)
    }


    // MARK: - Daily activity (Polar SDK 6.7)

    func processDailyActivity(_ activity: PolarActivityData, deviceId: String) {
        guard let samples = activity.samples else {
            NSLog("[PM][Activity] No samples for device \(deviceId)")
            return
        }

        // 1. Aggregate totals
        let totalSteps = samples.stepSamples?.reduce(0, +) ?? 0
        let avgMet = (samples.metSamples?.isEmpty == false)
            ? (samples.metSamples!.reduce(0, +) / Float(samples.metSamples!.count))
            : 0
        let start = samples.startTime
        let durationSecs = Double(samples.stepRecordingInterval * (samples.stepSamples?.count ?? 0))
        let date = Calendar.current.startOfDay(for: start)

        NSLog("[PM][Activity] \(deviceId) date=\(date) totalSteps=\(totalSteps) avgMET=\(avgMet) duration=\(durationSecs)s")

        // 2. Persist metrics
        _ = CTMetricsRepository.shared.upsert(
            kind: .steps,
            value: Double(totalSteps),
            unit: "steps",
            source: .polar360,
            date: date
        )

        _ = CTMetricsRepository.shared.upsert(
            kind: .sleepHours,
            value: durationSecs / 3600.0,
            unit: "h",
            source: .polar360,
            date: date
        )

        _ = CTMetricsRepository.shared.upsert(
            kind: .sdnn,
            value: Double(avgMet),
            unit: "MET",
            source: .polar360,
            date: date
        )

        // 3. Optional: derive activity class distribution
        let counts = Dictionary(grouping: samples.activityInfoList, by: \.activityClass)
            .mapValues { $0.count }
        for (cls, count) in counts {
            NSLog("[PM][Activity] \(cls.rawValue): \(count) samples")
        }
    }

    // MARK: - Helpers for sample rate & channels (used by offline PPG)

    static func extractSampleRateHz(from setting: PolarSensorSetting) -> UInt32? {
        setting.settings[.sampleRate]?.first
    }

    static func extractChannels(from setting: PolarSensorSetting) -> UInt32? {
        setting.settings[.channels]?.first
    }

    static func unpackDiskSpace(_ ds: PolarDiskSpaceData) -> (UInt32, UInt32)? {
        // Polar SDK 6.7 uses PolarDiskSpace
        let arr = Array(
            Mirror(reflecting: ds)
                .children
                .compactMap { $0.value as? UInt32 }
                .prefix(2)
        )
        guard arr.count == 2 else { return nil }
        return (arr[0], arr[1])
    }
}

extension PolarManager {

    /// Handles a full Polar 360 sleep packet (RHR + stages + metadata).
    func submitPolar360SleepPacket(_ packet: P360SleepPacket) {
        NSLog("[PM][Cloud] ingesting Polar360 sleep packet ending \(packet.sleepEnd)")

        // Persist average last-night RHR
        if let avg = packet.hrSeries.map(\.bpm).average() {
            _ = CTMetricsRepository.shared.upsert(
                kind: .restingHeartRate,
                value: avg,
                unit: "bpm",
                source: .polar360,
                date: packet.sleepEnd
            )
            NSLog("[PM][Cloud] stored RHR \(avg) bpm at \(packet.sleepEnd)")
        }

        // Store HR samples
        if !packet.hrSeries.isEmpty {
            for pt in packet.hrSeries {
                _ = CTMetricsRepository.shared.upsert(
                    kind: .heartRate,
                    value: pt.bpm,
                    unit: "bpm",
                    source: .polar360,
                    date: pt.ts
                )
            }
            NSLog("[PM][Cloud] stored \(packet.hrSeries.count) HR samples")
        }
    }

    /// Handles just the stage data portion of a Polar 360 packet.
    func submitPolar360SleepStages(from packet: P360SleepPacket) {
        NSLog("[PM][Cloud] ingesting Polar360 stage data")

        guard !packet.stages.isEmpty else {
            NSLog("[PM][Cloud] no stage data present")
            return
        }

        let segments: [SleepSegment] = packet.stages.compactMap { st in
            let mapped: SleepStage = {
                switch st.stage {
                case .awake: return .awake
                case .rem:   return .rem
                case .deep:  return .deep
                case .light: return .core            // Polar "light" sleep → Core sleep
                @unknown default:
                    return .core
                }
            }()

            return SleepSegment(
                stage: mapped,
                start: st.start,
                end: st.end,
                source: .ct360
            )
        }

        do {
            try SleepRepository.shared.upsertSegments(segments)
            NSLog("[PM][Cloud] stored \(segments.count) Polar360 segments in SleepRepository")
        } catch {
            NSLog("[PM][Cloud] ERROR storing Polar360 sleep segments: \(error.localizedDescription)")
        }
    }

    private func mapP360Stage(_ kind: P360SleepPacket.Stage) -> CTSleepStage {
        switch kind {
        case .awake: return .awake
        case .rem:   return .rem
        case .light: return .light
        case .deep:  return .deep
        @unknown default:
            return .light
        }
    }
}

// MARK: - Polar360SleepSource Implementation

final class PolarBleSleepSource: Polar360SleepSource {

    func fetchSleepSegments(
        deviceId: String,
        from: Date,
        to: Date,
        completion: @escaping (Swift.Result<[SleepSegment], Error>) -> Void
    ) {

        NSLog("[P360SleepSource] Fetching sleep for \(deviceId) range=\(from) → \(to)")

        Task {
            do {
                // Ask Polar cloud for raw sleep data
                let nights = try await PolarManager.shared.api.getSleepData(
                    identifier: deviceId,
                    fromDate: from,
                    toDate: to
                ).value

                NSLog("[P360SleepSource] Polar returned \(nights.count) nights")

                var out: [SleepSegment] = []

                for night in nights {

                    guard
                        let start = night.sleepStartTime,
                        let end = night.sleepEndTime,
                        let phases = night.sleepWakePhases,
                        !phases.isEmpty
                    else {
                        NSLog("[P360SleepSource] Skipping night with missing phase data")
                        continue
                    }

                    // Iterate phases and build segments
                    for (idx, phase) in phases.enumerated() {

                        let segStart = start.addingTimeInterval(
                            TimeInterval(phase.secondsFromSleepStart)
                        )

                        // End = next phase OR final end
                        let segEnd: Date = {
                            if idx + 1 < phases.count {
                                let next = phases[idx + 1]
                                return start.addingTimeInterval(
                                    TimeInterval(next.secondsFromSleepStart)
                                )
                            } else {
                                return end
                            }
                        }()

                        let stage: SleepStage = {
                            switch phase.state {
                            case .WAKE:        return .awake
                            case .REM:         return .rem
                            case .NONREM12:    return .core
                            case .NONREM3:     return .deep
                            case .UNKNOWN:     return .core
                            case .none:        return .awake
                            }
                        }()

                        if segEnd > segStart {
                            out.append(
                                SleepSegment(
                                    stage: stage,
                                    start: segStart,
                                    end: segEnd,
                                    source: .ct360
                                )
                            )
                        }
                    }
                }

                NSLog("[P360SleepSource] Mapped \(out.count) segments")

                completion(.success(out))

            } catch {
                NSLog("[P360SleepSource] ERROR: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

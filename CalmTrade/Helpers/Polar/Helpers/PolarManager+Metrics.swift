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
        guard !rrsMs.isEmpty else {
            debugPrint("=== POLAR RHR COMPUTATION DEBUG ===")
            debugPrint("No RR intervals received, skipping RHR calculation")
            debugPrint("===================================")
            return
        }

        debugPrint("=== POLAR RHR COMPUTATION DEBUG ===")
        debugPrint("Received \(rrsMs.count) RR intervals (in ms): \(rrsMs)")
        debugPrint("RR intervals range: \(rrsMs.min() ?? 0) - \(rrsMs.max() ?? 0) ms")

        // Convert RR → instantaneous HR (bpm) → median
        let bpmValues: [Double] = rrsMs.map {
            let bpm = 60000.0 / Double($0)
            debugPrint("RR interval \($0)ms → \(bpm) BPM")
            return bpm
        }

        let sorted = bpmValues.sorted()
        let median: Double = sorted[sorted.count / 2]
        let average: Double = bpmValues.reduce(0, +) / Double(bpmValues.count)

        debugPrint("BPM values: \(bpmValues)")
        debugPrint("Sorted BPM values: \(sorted)")
        debugPrint("Median RHR: \(median) BPM")
        debugPrint("Average RHR: \(average) BPM")
        debugPrint("===================================")

        // Enhanced RHR calculation with sleep data integration
        let enhancedRHR = calculateEnhancedRHR(rrsMs: rrsMs, source: source, date: Date())
        
        NSLog("[PM][RHR] computed RHR median \(enhancedRHR) bpm from \(rrsMs.count) RR samples")

        onRHRComputed?(enhancedRHR, source, deviceId)

        // Optional: persist to CTMetricsRepository
        _ = CTMetricsRepository.shared.upsert(kind: .restingHeartRate,
                                              value: enhancedRHR,
                                              unit: "bpm",
                                              source: source,
                                              date: Date())
    }
    
    // MARK: - Enhanced RHR calculation with sleep data integration
    
    private func calculateEnhancedRHR(rrsMs: [Int], source: CTMetricSource, deviceId: String) -> Double {
        // Basic RHR calculation
        let bpmValues: [Double] = rrsMs.map { 60000.0 / Double($0) }
        let sorted = bpmValues.sorted()
        let medianRHR = sorted[sorted.count / 2]
        
        // Get sleep data for the same day to enhance RHR calculation
        let sleepQualityMultiplier = getSleepQualityMultiplier(for: Date(), source: source)
        
        // Apply sleep quality adjustment to RHR
        let adjustedRHR = medianRHR * sleepQualityMultiplier
        
        // Additional enhancement: filter out outliers and focus on stable periods
        let filteredBPM = filterOutlierBPM(bpmValues)
        let filteredMedian = filteredBPM.isEmpty ? medianRHR : filteredBPM.sorted()[filteredBPM.count / 2]
        
        // Combine basic calculation with sleep-adjusted value
        let finalRHR = (adjustedRHR + filteredMedian) / 2.0
        
        debugPrint("Enhanced RHR calculation:")
        debugPrint("- Basic median RHR: \(medianRHR)")
        debugPrint("- Sleep quality multiplier: \(sleepQualityMultiplier)")
        debugPrint("- Adjusted RHR: \(adjustedRHR)")
        debugPrint("- Filtered median RHR: \(filteredMedian)")
        debugPrint("- Final enhanced RHR: \(finalRHR)")
        
        return finalRHR
    }
    
    // MARK: - Enhanced RHR calculation with specific date
    
    private func calculateEnhancedRHR(rrsMs: [Int], source: CTMetricSource, date: Date) -> Double {
        // Basic RHR calculation
        let bpmValues: [Double] = rrsMs.map { 60000.0 / Double($0) }
        let sorted = bpmValues.sorted()
        let medianRHR = sorted[sorted.count / 2]
        
        // Get sleep data for the previous night to enhance RHR calculation (more relevant)
        let sleepQualityMultiplier = getSleepQualityMultiplier(for: date, source: source)
        
        // Apply sleep quality adjustment to RHR
        let adjustedRHR = medianRHR * sleepQualityMultiplier
        
        // Additional enhancement: filter out outliers and focus on stable periods
        let filteredBPM = filterOutlierBPM(bpmValues)
        let filteredMedian = filteredBPM.isEmpty ? medianRHR : filteredBPM.sorted()[filteredBPM.count / 2]
        
        // Combine basic calculation with sleep-adjusted value
        let finalRHR = (adjustedRHR + filteredMedian) / 2.0
        
        debugPrint("Enhanced RHR calculation for date \(date):")
        debugPrint("- Basic median RHR: \(medianRHR)")
        debugPrint("- Sleep quality multiplier: \(sleepQualityMultiplier)")
        debugPrint("- Adjusted RHR: \(adjustedRHR)")
        debugPrint("- Filtered median RHR: \(filteredMedian)")
        debugPrint("- Final enhanced RHR: \(finalRHR)")
        
        return finalRHR
    }
    
    // MARK: - Sleep Quality Multiplier Calculation
    
    private func getSleepQualityMultiplier(for date: Date, source: CTMetricSource) -> Double {
        // Default multiplier if no sleep data is available
        var multiplier: Double = 1.0
        
        // Try to get sleep score from repository for the previous night (more relevant for RHR)
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: date) ?? date.addingTimeInterval(-86400)
        let startOfYesterday = cal.startOfDay(for: yesterday)
        let endOfYesterday = cal.startOfDay(for: date)
        
        // Get sleep score for the previous night (most relevant for today's RHR)
        if let sleepScoreValue = CTMetricsRepository.shared.series(
            kind: .sleepScore,
            from: startOfYesterday,
            to: endOfYesterday,
            source: source
        ).last?.value {
            // Normalize sleep score to multiplier (higher sleep score = better recovery = potentially lower RHR)
            // A good sleep score (high value) should result in a multiplier that reflects better recovery
            let normalizedScore = sleepScoreValue / 100.0
            // Invert the relationship: better sleep quality leads to lower RHR (better cardiovascular fitness)
            // So if sleep score is high, we might expect a slightly lower RHR
            multiplier = max(0.85, min(1.15, 1.05 - (normalizedScore * 0.1))) // Range 0.85-1.15
        } else {
            // If no sleep score, try to infer from sleep stages
            let sleepSegments = SleepRepository.shared.unifiedSegments(from: startOfYesterday, to: endOfYesterday)
            
            if !sleepSegments.isEmpty {
                // Calculate sleep efficiency based on deep sleep and total sleep time
                let deepSleepSegments = sleepSegments.filter { $0.stage == .deep }
                let remSleepSegments = sleepSegments.filter { $0.stage == .rem }
                let totalSleepTime = sleepSegments.reduce(0) { $0 + $0.end.timeIntervalSince($0.start) }
                let deepSleepTime = deepSleepSegments.reduce(0) { $0 + $0.end.timeIntervalSince($0.start) }
                let remSleepTime = remSleepSegments.reduce(0) { $0 + $0.end.timeIntervalSince($0.start) }
                
                if totalSleepTime > 0 {
                    let deepSleepRatio = deepSleepTime / totalSleepTime
                    let remSleepRatio = remSleepTime / totalSleepTime
                    
                    // Better sleep quality indicators (adequate deep and REM sleep) suggest better recovery
                    // This might correlate with lower RHR (better cardiovascular fitness)
                    let sleepQualityIndex = (deepSleepRatio * 0.6) + (remSleepRatio * 0.4)
                    multiplier = max(0.85, min(1.15, 1.05 - (sleepQualityIndex * 0.15))) // Adjust based on sleep quality
                }
            }
        }
        
        return multiplier
    }
    
    // MARK: - RHR calculation with sleep stage correlation
    
    /// Calculates RHR with correlation to sleep stages for more accurate results
    /// Uses RR intervals during deep sleep periods when the body is most at rest
    func computeRestingHeartRateWithSleepCorrelation(
        from rrsMs: [Int], 
        source: CTMetricSource, 
        deviceId: String,
        sleepSegments: [SleepSegment]? = nil
    ) {
        guard !rrsMs.isEmpty else {
            debugPrint("=== POLAR RHR COMPUTATION WITH SLEEP CORRELATION DEBUG ===")
            debugPrint("No RR intervals received, skipping RHR calculation")
            debugPrint("===================================")
            return
        }

        debugPrint("=== POLAR RHR COMPUTATION WITH SLEEP CORRELATION DEBUG ===")
        debugPrint("Received \(rrsMs.count) RR intervals (in ms): \(rrsMs)")
        debugPrint("RR intervals range: \(rrsMs.min() ?? 0) - \(rrsMs.max() ?? 0) ms")

        // Convert RR → instantaneous HR (bpm)
        let bpmValues: [Double] = rrsMs.map {
            let bpm = 60000.0 / Double($0)
            debugPrint("RR interval \($0)ms → \(bpm) BPM")
            return bpm
        }

        // If sleep segments are provided, use them to weight the RHR calculation
        let finalRHR: Double
        if let sleepSegs = sleepSegments, !sleepSegs.isEmpty {
            // Calculate weighted RHR based on sleep stages
            finalRHR = calculateWeightedRHR(bpmValues: bpmValues, sleepSegments: sleepSegs)
        } else {
            // Fall back to the enhanced calculation with sleep quality multiplier
            finalRHR = calculateEnhancedRHR(rrsMs: rrsMs, source: source, date: Date())
        }

        debugPrint("BPM values: \(bpmValues)")
        debugPrint("Final RHR with sleep correlation: \(finalRHR)")
        debugPrint("===================================")

        NSLog("[PM][RHR] computed RHR with sleep correlation \(finalRHR) bpm from \(rrsMs.count) RR samples")

        onRHRComputed?(finalRHR, source, deviceId)

        // Persist to CTMetricsRepository
        _ = CTMetricsRepository.shared.upsert(kind: .restingHeartRate,
                                              value: finalRHR,
                                              unit: "bpm",
                                              source: source,
                                              date: Date())
    }
    
    // MARK: - Weighted RHR calculation based on sleep stages
    
    private func calculateWeightedRHR(bpmValues: [Double], sleepSegments: [SleepSegment]) -> Double {
        // Create a mapping of time periods to sleep stages
        let sortedBPM = bpmValues.sorted()
        let medianRHR = sortedBPM[sortedBPM.count / 2]
        
        // Calculate weights based on sleep stages
        // Deep sleep and REM sleep periods are considered optimal for RHR measurement
        var deepSleepWeight: Double = 0
        var remSleepWeight: Double = 0
        var lightSleepWeight: Double = 0
        var awakeWeight: Double = 0
        
        for segment in sleepSegments {
            let duration = segment.end.timeIntervalSince(segment.start)
            switch segment.stage {
            case .deep:
                deepSleepWeight += duration
            case .rem:
                remSleepWeight += duration
            case .core: // Light sleep
                lightSleepWeight += duration
            case .awake:
                awakeWeight += duration
            }
        }
        
        let totalSleepTime = deepSleepWeight + remSleepWeight + lightSleepWeight + awakeWeight
        
        if totalSleepTime > 0 {
            // Weight RHR calculation based on sleep quality
            // Deep sleep and REM sleep contribute more to accurate RHR
            let deepSleepRatio = deepSleepWeight / totalSleepTime
            let remSleepRatio = remSleepWeight / totalSleepTime
            let lightSleepRatio = lightSleepWeight / totalSleepTime
            let awakeRatio = awakeWeight / totalSleepTime
            
            // Adjust RHR based on sleep composition
            // More deep sleep generally correlates with better recovery and lower RHR
            let sleepCompositionAdjustment = 1.0 - (deepSleepRatio * 0.05) - (remSleepRatio * 0.03)
            
            // Filter BPM values that occurred during deep sleep periods if possible
            // For now, we'll apply the sleep composition adjustment
            return medianRHR * sleepCompositionAdjustment
        } else {
            // If no sleep data, return the median
            return medianRHR
        }
    }
    
    // MARK: - Outlier Filtering
    
    private func filterOutlierBPM(_ bpmValues: [Double]) -> [Double] {
        guard !bpmValues.isEmpty else { return [] }
        
        let sorted = bpmValues.sorted()
        let q1Index = Int(Double(sorted.count) * 0.25)
        let q3Index = Int(Double(sorted.count) * 0.75)
        
        // Calculate interquartile range (IQR)
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1
        
        // Define outlier bounds
        let lowerBound = q1 - (1.5 * iqr)
        let upperBound = q3 + (1.5 * iqr)
        
        // Filter values within bounds
        return bpmValues.filter { value in
            value >= lowerBound && value <= upperBound
        }
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

        // Store the Polar sleep score as a separate metric
        if let sleepScore = sleep.userSleepRating?.rawValue {
            _ = CTMetricsRepository.shared.upsert(
                kind: .sleepScore,
                value: Double(sleepScore),
                unit: "",
                source: .polar360,
                date: end
            )
            debugPrint("=== POLAR SLEEP SCORE STORED ===")
            debugPrint("Polar sleep score: \(sleepScore)")
            debugPrint("Date: \(end)")
            debugPrint("================================")
        }
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

        // Check if sleep API feature is available for this device
        // Note: Using activity data feature as proxy since iOS SDK doesn't have explicit sleep feature
        let isActivityFeatureAvailable = PolarManager.shared.api.isFeatureReady(deviceId, feature: .feature_polar_activity_data)
        
        if !isActivityFeatureAvailable {
            NSLog("[P360SleepSource] Activity feature not ready for device \(deviceId), scheduling delayed fetch")
            
            // Schedule a delayed fetch after a short delay to allow features to become ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task {
                    do {
                        let nights = try await PolarManager.shared.api.getSleepData(
                            identifier: deviceId,
                            fromDate: from,
                            toDate: to
                        ).value
                        
                        let processedNights = self.processSleepNights(nights)
                        completion(.success(processedNights))
                    } catch {
                        NSLog("[P360SleepSource] Delayed fetch ERROR: \(error.localizedDescription)")
                        // Return empty array instead of failing completely to avoid blocking the app
                        completion(.success([]))
                    }
                }
            }
            return
        }

        Task {
            do {
                // Ask Polar cloud for raw sleep data
                let nights = try await PolarManager.shared.api.getSleepData(
                    identifier: deviceId,
                    fromDate: from,
                    toDate: to
                ).value

                NSLog("[P360SleepSource] Polar returned \(nights.count) nights")

                let processedNights = self.processSleepNights(nights)
                completion(.success(processedNights))

            } catch {
                NSLog("[P360SleepSource] ERROR: \(error.localizedDescription)")
                // Return empty array instead of failing completely to avoid blocking the app
                completion(.success([]))
            }
        }
    }
    
    private func processSleepNights(_ nights: [PolarSleepData.PolarSleepAnalysisResult]) -> [SleepSegment] {
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

            // Sort phases by time to ensure correct chronological order
            let sortedPhases = phases.sorted { $0.secondsFromSleepStart < $1.secondsFromSleepStart }
            
            // Iterate phases and build segments
            for (idx, phase) in sortedPhases.enumerated() {
                let segStart = start.addingTimeInterval(
                    TimeInterval(phase.secondsFromSleepStart)
                )

                // End = next phase OR final end
                let segEnd: Date = {
                    if idx + 1 < sortedPhases.count {
                        let next = sortedPhases[idx + 1]
                        return start.addingTimeInterval(
                            TimeInterval(next.secondsFromSleepStart)
                        )
                    } else {
                        // Use the actual sleep end time to ensure accuracy
                        return end
                    }
                }()

                let stage: SleepStage = {
                    switch phase.state {
                    case .WAKE:        return .awake
                    case .REM:         return .rem
                    case .NONREM12:    return .core
                    case .NONREM3:     return .deep
                    case .UNKNOWN:     return .core  // Keeping as core to maintain compatibility
                    case .none:        return .awake
                    }
                }()

                if segEnd > segStart {
                    // Additional validation to ensure the segment is within the sleep window
                    let validatedStart = max(segStart, start)
                    let validatedEnd = min(segEnd, end)
                    
                    if validatedEnd > validatedStart {
                        out.append(
                            SleepSegment(
                                stage: stage,
                                start: validatedStart,
                                end: validatedEnd,
                                source: .ct360
                            )
                        )
                    }
                }
            }
        }
        
        NSLog("[P360SleepSource] Mapped \(out.count) segments")
        return out
    }
}

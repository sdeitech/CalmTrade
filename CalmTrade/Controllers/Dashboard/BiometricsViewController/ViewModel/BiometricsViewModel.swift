//
//  BiometricsViewModel.swift
//  CalmTrade
//
//  Repo-first view model. Heavy work off main, debounced.
//  Sleep hours match SleepInsight (HK union w/ unspecified→core) with repo fallbacks.
//  Gauge TrendData.sleepHours & sleepIsUp are overridden to use the same value.
//

import Foundation
import Combine
import HealthKit

// MARK: - Internal Steps provider (thin wrapper)
private protocol StepsSource {
    func stepsToday() -> Double
    func stepsAverage(lastNDays: Int) -> Double?
}

private final class RepoStepsSource: StepsSource {
    func stepsToday() -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return StepEngine.stepsTotal(from: start, to: Date())
    }
    func stepsAverage(lastNDays n: Int) -> Double? {
        guard n > 0 else { return nil }
        let cal = Calendar.current
        var total = 0.0
        for i in 0..<n {
            let d0 = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: Date()))!
            let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
            total += StepEngine.stepsTotal(from: d0, to: d1)
        }
        return total / Double(n)
    }
}

// MARK: - Sleep Score tile model
struct SleepScoreTile {
    let score: Int
    let date: Date
    let source: CTMetricSource
}

// MARK: - ViewModel
final class BiometricsViewModel: ObservableObject {

    // MARK: - Dependencies
    private let repo = CTMetricsRepository.shared
    private let stepsSource: StepsSource = RepoStepsSource()
    private let healthStore = HKHealthStore()

    // MARK: - Published (SwiftUI)
    @Published var heartRate: Double?
    @Published var rmssd: Double?
    @Published var sdnn: Double?
    @Published var restingHeartRate: Double?
    @Published var sleepHours: Double?
    @Published var steps: Double?

    // MARK: - Outputs (UIKit / SwiftUI)
    var onSleepScoreDidUpdate: ((SleepScoreTile?) -> Void)?
    var onDataUpdated: ((BiometricData) -> Void)?
    var onPropsUpdate: ((CalmScoreTileProps) -> Void)?

    // State
    private var hubToken: UUID?
    private(set) var biometricData = BiometricData()
    private var lastCalmProps: CalmScoreTileProps?

    // Track last update times for data freshness
    private var lastRmssdUpdate: Date?
    private var lastSdnnUpdate: Date?
    private var lastHrUpdate: Date?
    private var lastRhrUpdate: Date?

    // Work queue + coalescing
    private let workQ = DispatchQueue(label: "ct.biometrics.vm", qos: .userInitiated)
    private var pendingWork: DispatchWorkItem?

    // MARK: - Lifecycle
    func start() {
        _installObserversIfNeeded()
        // print("=== BiometricsViewModel Full HealthKit Data ===")
        // print("Latest HR: \(String(describing: repo.latestValue(kind: .heartRate)?.value))")
        // print("Latest RMSSD: \(String(describing: repo.latestValue(kind: .rmssd)?.value))")
        // print("Latest SDNN: \(String(describing: repo.latestValue(kind: .sdnn)?.value))")
        // print("Latest Resting HR: \(String(describing: repo.latestValue(kind: .restingHeartRate)?.value))")

        // Print sleep data from different sources
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let sleepCoreData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
        let sleepDeepData = repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
        let sleepREMData = repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)
        let sleepAwakeData = repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)
        let sleepScoreData = repo.series(kind: .sleepScore, from: today, to: tomorrow, source: .polar360)

        debugPrint("Polar360 SleepCore data: \(sleepCoreData.map { "\($0.value)s at \($0.date)" })")
        debugPrint("Polar360 SleepDeep data: \(sleepDeepData.map { "\($0.value)s at \($0.date)" })")
        debugPrint("Polar360 SleepREM data: \(sleepREMData.map { "\($0.value)s at \($0.date)" })")
        debugPrint("Polar360 SleepAwake data: \(sleepAwakeData.map { "\($0.value)s at \($0.date)" })")
        debugPrint("Polar360 SleepScore data: \(sleepScoreData.map { "\($0.value) at \($0.date)" })")

        debugPrint("SleepRepository latest night: \(String(describing: SleepRepository.shared.latestNight()))")
        // print("===============================================")

        scheduleFullRefresh()
        // Add a small delay to ensure sleep data is loaded after other data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self._refreshSleepScore()
        }
    }
    func stop() {
        NotificationCenter.default.removeObserver(self)
        if let t = hubToken { CalmScoreHub.shared.removeListener(t) }
        hubToken = nil
    }

    // MARK: - CalmScore hub (override sleep trend fields)
    func startLiveUpdates() {
        hubToken = CalmScoreHub.shared.addListener { [weak self] _, _, props in
            guard let self else { return }
            // Remember base props; we'll override sleep before emitting.
            self.lastCalmProps = props
            // print("=== BiometricsViewModel Hub Props ===")
            // print("Score: \(props.score)")
            // print("HRV: \(props.trend.hrvMs) ms (up: \(props.trend.hrvIsUp))")
            // print("HR: \(props.trend.hrBpm) bpm (down: \(props.trend.hrIsDown))")
            // print("Sleep: \(props.trend.sleepHours) hours (up: \(props.trend.sleepIsUp))")
            // print("Device Source: \(props.deviceSource.rawValue)")
            // print("Is Streaming: \(props.isStreaming)")
            // print("Last Update: \(props.lastUpdate)")
            // print("Battery Percent: \(String(describing: props.batteryPercent))")
            // print("=====================================")
            self.scheduleFullRefresh()
        }
        scheduleFullRefresh()
    }
    func stopLiveUpdates() {
        if let t = hubToken { CalmScoreHub.shared.removeListener(t) }
        hubToken = nil
    }

    // MARK: - Refresh pipeline (debounced, off-main)
    private func scheduleFullRefresh(force: Bool = false) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Validate data freshness on forced refresh
            if force {
                self.validateDataFreshness()
            }

            // Read everything cheap/synchronous first (off-main)
            let hr   = self.repo.latestValue(kind: .heartRate)?.value
            let rm   = self.repo.latestValue(kind: .rmssd)?.value
            let sd   = self.repo.latestValue(kind: .sdnn)?.value
            let rhr  = self.repo.latestValue(kind: .restingHeartRate)?.value

            // Unified sleep hours from repository (Polar360 > HealthKit)
            let now = Date()
            let stepsToday = self.stepsSource.stepsToday()

            // Try to get sleep data from SleepRepository first
            var todaySleep = SleepRepository.shared.latestNight()?.hours

            // print("=== BiometricsViewModel HealthKit Access ===")
            // print("SleepRepository latest night: \(String(describing: SleepRepository.shared.latestNight()))")

            // If no sleep data from repository, try to get from HealthKit directly
            if todaySleep == nil {
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                // Check for sleep data in HealthKit
                let sleepCoreData = self.repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                let sleepDeepData = self.repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                let sleepREMData = self.repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                debugPrint("Polar360 SleepCore data count: \(sleepCoreData.count)")
                debugPrint("Polar360 SleepDeep data count: \(sleepDeepData.count)")
                debugPrint("Polar360 SleepREM data count: \(sleepREMData.count)")

                let sleepData = sleepCoreData + sleepDeepData + sleepREMData

                debugPrint("Total Polar360 sleep data count: \(sleepData.count)")

                if !sleepData.isEmpty {
                    todaySleep = sleepData.reduce(0.0) { $0 + $1.value } / 3600.0
                    debugPrint("Calculated todaySleep from Polar360: \(todaySleep!) hours")
                } else {
                    debugPrint("No sleep data found in Polar360 for today")
                }
            } else {
                // print("Using sleep data from SleepRepository: \(todaySleep!) hours")
            }

            // Calculate sleep time based on raw Polar data (from sleep start to end)
            var todaySleepRaw: Double? = nil

            // Try to get raw sleep time from SleepRepository (from sleep start to end)
            if let latestNight = SleepRepository.shared.latestNight() {
                // Calculate total time from sleep start to end (including awake periods)
                // Try to get the unified sleep segments from the repository
                let cal = Calendar.current
                let today = cal.startOfDay(for: latestNight.date)
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                // Get unified sleep segments from SleepRepository
                let unifiedSegments = SleepRepository.shared.unifiedSegments(from: today, to: tomorrow)

                if !unifiedSegments.isEmpty {
                    let sleepStart = unifiedSegments.min { $0.start < $1.start }?.start ?? Date()
                    let sleepEnd = unifiedSegments.max { $0.end < $1.end }?.end ?? Date()

                    let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
                    todaySleepRaw = totalSleepTime

                    debugPrint("Raw Polar sleep calculation: Start=\(sleepStart), End=\(sleepEnd), Total=\(totalSleepTime) hours")
                } else {
                    // Alternative: Get all sleep segments for this night to calculate raw time from the metrics repo
                    let allSegments = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)

                    if !allSegments.isEmpty {
                        let sleepStart = allSegments.min { $0.date < $1.date }?.date ?? Date()
                        let sleepEnd = allSegments.max { $0.date < $1.date }?.date ?? Date()

                        let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
                        todaySleepRaw = totalSleepTime

                        debugPrint("Raw Polar sleep calculation: Start=\(sleepStart), End=\(sleepEnd), Total=\(totalSleepTime) hours")
                    } else {
                        // Fallback to the original hours if no segments found
                        todaySleepRaw = latestNight.hours
                        debugPrint("Using fallback calculation: \(latestNight.hours) hours")
                    }
                }
            }

            // Use raw calculation instead of sum of sleep segments
            todaySleep = todaySleepRaw

            // Previous-night unified sleep
            let prevAnchor = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
            var prevNightRaw: Double? = nil

            if let prevNightObj = self.latestNightBefore(date: prevAnchor) {
                // For the previous night, we'll use the hours value since it's already calculated
                // The latestNightBefore function returns (date: Date, hours: Double) tuple
                prevNightRaw = prevNightObj.hours
            }

            // print("Previous night sleep: \(String(describing: prevNight))")
            // print("===========================================")

            let sleepIsUp: Bool = {
                guard let cur = todaySleep, let prev = prevNightRaw else {
                    return self.lastCalmProps?.trend.sleepIsUp ?? true
                }
                return cur >= prev
            }()

            // Build UI data using unified sleep
            let labelData = self._buildLabelData(
                now: now,
                stepsToday: stepsToday,
                chosenSleepHours: todaySleep
            )

            // Print sleep data being retrieved
            // print("=== BiometricsViewModel Sleep Data ===")
            // print("Today's sleep hours: \(String(describing: todaySleep))")
            // print("Previous night sleep: \(String(describing: prevNight))")
            // print("Sleep is up: \(sleepIsUp)")
            // print("=====================================")

            // Override gauge props (sleep only)
            self.emitGaugeProps(
                overridingSleepHours: todaySleep,
                isUp: sleepIsUp
            )

            DispatchQueue.main.async {
                self.heartRate        = hr
                self.rmssd            = rm
                self.sdnn             = sd
                self.restingHeartRate = rhr
                self.sleepHours       = todaySleep
                self.steps            = stepsToday

                self.biometricData = labelData
                self.onDataUpdated?(labelData)
            }
        }
        pendingWork = work
        workQ.asyncAfter(deadline: .now() + (force ? 0.0 : 0.15), execute: work) // Immediate refresh if forced
    }

    // Validate data freshness and mark stale data appropriately
    private func validateDataFreshness() {
        let now = Date()
        let staleThreshold: TimeInterval = 3600 // 1 hour threshold

        // Check if RMSSD data is stale
        if let lastUpdate = lastRmssdUpdate,
           now.timeIntervalSince(lastUpdate) > staleThreshold {
            // Update biometricData to show stale status
            var data = biometricData
            data.rmssdLatest = "—"
            data.rmssdAverage = "—"
            data.rmssdTimestamp = "Data unavailable"
            biometricData = data
        }

        // Check if SDNN data is stale
        if let lastUpdate = lastSdnnUpdate,
           now.timeIntervalSince(lastUpdate) > staleThreshold {
            var data = biometricData
            data.sdnnLatest = "—"
            data.sdnnAverage = "—"
            data.sdnnTimestamp = "Data unavailable"
            biometricData = data
        }
    }


    // Build the label model entirely off-main
    private func _buildLabelData(now: Date, stepsToday: Double, chosenSleepHours: Double?) -> BiometricData {
        var data = biometricData
        data.lastUpdateTimestamp = "Last update \(formatFullTimestamp(now))"

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -2, to: now) ?? now.addingTimeInterval(-172800)

        func latestFromSeries(kind: CTMetricKind, source: CTMetricSource? = nil) -> (value: Double, date: Date)? {
            let samples = repo.series(kind: kind, from: start, to: now, source: source)
            guard let s = samples.max(by: { $0.date < $1.date }) else { return nil }
            return (s.value, s.date)
        }

        // Heart Rate
        if let latest = repo.latestValue(kind: .heartRate) {
            let v = latest.value
            data.heartRateLatest  = "\(Int(v))"
            data.heartRateAverage = "\(Int(v))"
        } else { data.heartRateLatest = "--"; data.heartRateAverage = "--" }

        // RMSSD
        if let (v, d) =
            latestFromSeries(kind: .rmssd, source: .polar360) ??
            latestFromSeries(kind: .rmssd, source: .polarH10) ??
            latestFromSeries(kind: .rmssd, source: nil) {
            data.rmssdLatest = "\(Int(v))"; data.rmssdAverage = "\(Int(v))"; data.rmssdTimestamp = formatTimeStamp(d)
            data.lastRmssdUpdate = d // Track last RMSSD update time in BiometricData
            lastRmssdUpdate = d // Also track in ViewModel
        } else {
            data.rmssdLatest = "--"; data.rmssdAverage = "--"; data.rmssdTimestamp = ""
            data.lastRmssdUpdate = Date() // Set to current time when no data
            // Only update lastRmssdUpdate if we had a previous value and it's been stale for a while
            if lastRmssdUpdate == nil {
                lastRmssdUpdate = Date()
            }
        }

        // SDNN
        if let (v, d) =
            latestFromSeries(kind: .sdnn, source: .polar360) ??
            latestFromSeries(kind: .sdnn, source: .polarH10) ??
            latestFromSeries(kind: .sdnn, source: .appleHealth) ??
            latestFromSeries(kind: .sdnn, source: nil) {
            data.sdnnLatest = "\(Int(v))"; data.sdnnAverage = "\(Int(v))"; data.sdnnTimestamp = formatTimeStamp(d)
            data.lastSdnnUpdate = d // Track last SDNN update time in BiometricData
            lastSdnnUpdate = d // Also track in ViewModel
        } else {
            data.sdnnLatest = "--"; data.sdnnAverage = "--"; data.sdnnTimestamp = ""
            data.lastSdnnUpdate = Date() // Set to current time when no data
            if lastSdnnUpdate == nil {
                lastSdnnUpdate = Date()
            }
        }

        // Resting HR
        if let (v, d) = latestFromSeries(kind: .restingHeartRate, source: nil) {
            data.restingHeartRateLatest = "\(Int(v))"
            data.restingHeartRateAverage = "\(Int(v))"
            data.restingHeartRateTimestamp = formatTimeStamp(d)
            data.lastRhrUpdate = d // Track last RHR update time in BiometricData
            lastRhrUpdate = d // Also track in ViewModel
        } else {
            data.restingHeartRateLatest = "--"; data.restingHeartRateAverage = "--"; data.restingHeartRateTimestamp = ""
            data.lastRhrUpdate = Date() // Set to current time when no data
            if lastRhrUpdate == nil {
                lastRhrUpdate = Date()
            }
        }

        // Sleep (unified, same as SleepInsight)
        // print("=== BiometricsViewModel _buildLabelData Sleep Section ===")
        // print("chosenSleepHours: \(String(describing: chosenSleepHours))")

        if let h = chosenSleepHours {
            data.sleepTotal = formatHours(h)
            // print("Using chosenSleepHours: \(h)")

            if let night = SleepRepository.shared.latestNight() {
                data.sleepDate = formatDate(night.date)
                // print("Using SleepRepository night date: \(night.date)")
            } else {
                // print("No SleepRepository night data, using today's date")
                data.sleepDate = formatDate(Date())
            }
        } else {
            // print("No chosenSleepHours, trying repository...")
            // If no chosen sleep hours, try to get from repository
            if let latestNight = SleepRepository.shared.latestNight() {
                // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
                // Try to get the unified sleep segments from the repository first
                let cal = Calendar.current
                let today = cal.startOfDay(for: latestNight.date)
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                // Get unified sleep segments from SleepRepository
                let unifiedSegments = SleepRepository.shared.unifiedSegments(from: today, to: tomorrow)

                var totalSleepTime: Double
                if !unifiedSegments.isEmpty {
                    let sleepStart = unifiedSegments.min { $0.start < $1.start }?.start ?? Date()
                    let sleepEnd = unifiedSegments.max { $0.end < $1.end }?.end ?? Date()
                    totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                    data.sleepTotal = formatHours(totalSleepTime)  // Use raw calculation
                    debugPrint("Using raw Polar calculation: \(totalSleepTime) hours from \(sleepStart) to \(sleepEnd)")
                } else {
                    // Alternative: Get all sleep segments for this night to calculate raw time from the metrics repo
                    let allSegments = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)
                                  + repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)

                    if !allSegments.isEmpty {
                        let sleepStart = allSegments.min { $0.date < $1.date }?.date ?? Date()
                        let sleepEnd = allSegments.max { $0.date < $1.date }?.date ?? Date()
                        totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                        data.sleepTotal = formatHours(totalSleepTime)  // Use raw calculation
                        debugPrint("Using raw Polar calculation: \(totalSleepTime) hours from \(sleepStart) to \(sleepEnd)")
                    } else {
                        // Fallback to the original hours if no segments found
                        totalSleepTime = latestNight.hours
                        data.sleepTotal = formatHours(latestNight.hours)  // Use original calculation
                        debugPrint("Using fallback calculation: \(latestNight.hours) hours")
                    }
                }

                data.sleepDate = formatDate(latestNight.date)
                // print("Using SleepRepository latest night: \(latestNight.hours) hours at \(latestNight.date)")
            } else {
                // print("No SleepRepository latest night, trying fallback...")
                // Try to get from repo series as fallback
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                // Check for Polar sleep data specifically
                let polarSleepData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                if !polarSleepData.isEmpty {
                    // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
                    let sleepStart = polarSleepData.min { $0.date < $1.date }?.date ?? Date()
                    let sleepEnd = polarSleepData.max { $0.date < $1.date }?.date ?? Date()
                    let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                    data.sleepTotal = formatHours(totalSleepTime)  // Use raw calculation
                    data.sleepDate = formatDate(today)
                    debugPrint("Using raw Polar calculation: \(totalSleepTime) hours from \(sleepStart) to \(sleepEnd)")
                } else {
                    // print("No Polar360 sleep data, checking Apple Health...")

                    // Check Apple Health sleep data
                    let asleep = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .appleHealth)
                              + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .appleHealth)
                              + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .appleHealth)

                    if !asleep.isEmpty {
                        // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
                        let sleepStart = asleep.min { $0.date < $1.date }?.date ?? Date()
                        let sleepEnd = asleep.max { $0.date < $1.date }?.date ?? Date()
                        let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                        data.sleepTotal = formatHours(totalSleepTime)  // Use raw calculation
                        data.sleepDate = formatDate(today)
                        debugPrint("Using raw Apple Health calculation: \(totalSleepTime) hours from \(sleepStart) to \(sleepEnd)")
                    } else {
                        // print("No sleep data found in repositories, falling back to hub data...")

                        // Fallback: Use sleep data from the hub if available
                        if let hubSleepHours = lastCalmProps?.trend.sleepHours, hubSleepHours > 0 {
                            data.sleepTotal = formatHours(hubSleepHours)
                            data.sleepDate = formatDate(Date())
                            // print("Using hub sleep data: \(hubSleepHours) hours")
                        } else {
                            // print("No sleep data available anywhere, showing placeholder")
                            data.sleepTotal = "--"
                            data.sleepDate = ""
                        }
                    }
                }
            }
        }

        // print("Final sleepTotal: \(String(describing: data.sleepTotal))")
        // print("Final sleepDate: \(String(describing: data.sleepDate))")
        // print("==================================================")


        // Steps (today + 7-day avg)
        // Let's debug which source data we're getting
        debugPrint("=== BiometricsViewModel Steps Debug ===")
        let polarStepsToday = StepEngine.seriesPerMinute(from: cal.startOfDay(for: Date()), to: Date()).filter { point in
            guard let sourceData = repo.latestValue(kind: .steps, source: .polar360) else { return false }
            return abs(point.0.timeIntervalSince(sourceData.date)) < 3600 // Within 1 hour
        }.reduce(0) { $0 + $1.1 }

        let appleStepsToday = StepEngine.seriesPerMinute(from: cal.startOfDay(for: Date()), to: Date()).filter { point in
            guard let sourceData = repo.latestValue(kind: .steps, source: .appleHealth) else { return false }
            return abs(point.0.timeIntervalSince(sourceData.date)) < 3600 // Within 1 hour
        }.reduce(0) { $0 + $1.1 }

        debugPrint("Steps Today (Raw): \(stepsToday)")
        debugPrint("Polar steps today (estimated): \(polarStepsToday)")
        debugPrint("Apple Health steps today (estimated): \(appleStepsToday)")
        debugPrint("Using source with higher priority (Polar360 > Apple Health)")
        debugPrint("======================================")

        data.stepsToday = "\(Int(stepsToday))"
        data.stepsDate  = formatDate(now)
        var sum7 = 0.0
        for i in 0..<7 {
            let d0 = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: now))!
            let d1 = cal.date(byAdding: .day, value: 1, to: d0)!
            sum7 += StepEngine.stepsTotal(from: d0, to: d1)
        }
        data.stepsWeeklyAverage = "\(Int(round(sum7 / 7.0)))"

        return data
    }

    // MARK: - Gauge props override (sleep only)
    private func emitGaugeProps(overridingSleepHours hours: Double?, isUp: Bool) {
        let base = lastCalmProps ?? CalmScoreTileProps(
            score: 0,
            lastUpdate: Date(),
            deviceSource: .appleHK,
            isStreaming: false,
            trend: TrendData(hrvMs: 0, hrvIsUp: true, hrBpm: 0, hrIsDown: true, sleepHours: 0, sleepIsUp: true)
        )

        // Only override sleep data if we have valid sleep data from repository
        // Otherwise, preserve the original sleep data from the hub
        let updatedTrend = TrendData(
            hrvMs: base.trend.hrvMs,
            hrvIsUp: base.trend.hrvIsUp,
            hrBpm: base.trend.hrBpm,
            hrIsDown: base.trend.hrIsDown,
            sleepHours: hours ?? base.trend.sleepHours, // Use repository data if available, otherwise preserve original
            sleepIsUp: hours != nil ? isUp : base.trend.sleepIsUp // Only update direction if we have new data
        )

        let newProps = CalmScoreTileProps(
            score: base.score,
            lastUpdate: Date(),
            deviceSource: base.deviceSource,
            isStreaming: base.isStreaming,
            trend: updatedTrend
        )

        // Print the data we're getting from Health app in the ViewModel
        // print("=== BiometricsViewModel Health Data ===")
        // print("Score: \(newProps.score)")
        // print("HRV: \(newProps.trend.hrvMs) ms (up: \(newProps.trend.hrvIsUp))")
        // print("HR: \(newProps.trend.hrBpm) bpm (down: \(newProps.trend.hrIsDown))")
        // print("Sleep: \(newProps.trend.sleepHours) hours (up: \(newProps.trend.sleepIsUp))")
        // print("Device Source: \(newProps.deviceSource.rawValue)")
        // print("Is Streaming: \(newProps.isStreaming)")
        // print("Last Update: \(newProps.lastUpdate)")
        // print("=========================================")

        lastCalmProps = newProps
        DispatchQueue.main.async { self.onPropsUpdate?(newProps) }
    }

    // MARK: - Observers
    private func _installObserversIfNeeded() {
        NotificationCenter.default.removeObserver(self)

        NotificationCenter.default.addObserver(forName: .ctMetricsDidMirror, object: nil, queue: nil) { [weak self] _ in
            self?.scheduleFullRefresh()
        }

        NotificationCenter.default.addObserver(forName: .ctMetricUpdated, object: nil, queue: nil) { [weak self] note in
            if let kind = note.userInfo?["kind"] as? String, kind == "steps" {
                StepEngine.invalidateCache()
            }
            self?.scheduleFullRefresh()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(_refreshSleepScore), name: .ctSleepUpdated, object: nil)
    }

    // MARK: - Sleep Score logic (updated to prioritize Polar sleep score)
    @objc private func _refreshSleepScore() {
        // print("=== BiometricsViewModel _refreshSleepScore ===")

        // Prefer explicit numeric Sleep Score if available - prioritize Polar score over Apple Health
        let sleepScores = [repo.latestValue(kind: .sleepScore, source: .polar360),
                           repo.latestValue(kind: .sleepScore, source: .appleHealth)]
            .compactMap({ $0 })
        
        // Prioritize Polar scores first, then Apple Health if no Polar data
        if let latestPolarScore = sleepScores.filter({ $0.source == .polar360 }).max(by: { $0.date < $1.date }) {
            debugPrint("Found Polar sleep score: \(latestPolarScore.value) from \(latestPolarScore.source.rawValue) at \(latestPolarScore.date)")
            onSleepScoreDidUpdate?(SleepScoreTile(score: Int(latestPolarScore.value.rounded()), date: latestPolarScore.date, source: latestPolarScore.source))
            return
        } else if let latestAppleHealthScore = sleepScores.filter({ $0.source == .appleHealth }).max(by: { $0.date < $1.date }) {
            debugPrint("Found Apple Health sleep score: \(latestAppleHealthScore.value) from \(latestAppleHealthScore.source.rawValue) at \(latestAppleHealthScore.date)")
            onSleepScoreDidUpdate?(SleepScoreTile(score: Int(latestAppleHealthScore.value.rounded()), date: latestAppleHealthScore.date, source: latestAppleHealthScore.source))
            return
        } else {
            // print("No explicit sleep score found")
        }

        // First, try to get sleep hours from SleepRepository (which should include Polar data)
        if let latestNight = SleepRepository.shared.latestNight() {
            // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
            // Try to get the unified sleep segments from the repository first
            let cal = Calendar.current
            let today = cal.startOfDay(for: latestNight.date)
            let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

            // Get unified sleep segments from SleepRepository
            let unifiedSegments = SleepRepository.shared.unifiedSegments(from: today, to: tomorrow)

            var totalSleepTime: Double = 0
            if !unifiedSegments.isEmpty {
                let sleepStart = unifiedSegments.min { $0.start < $1.start }?.start ?? Date()
                let sleepEnd = unifiedSegments.max { $0.end < $1.end }?.end ?? Date()
                totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                // Only proceed if we have a valid sleep time
                if totalSleepTime > 0 {
                    // Calculate sleep score using Polar-style algorithm
                    let totalScore = calculatePolarStyleSleepScore(
                        sleepStart: sleepStart,
                        sleepEnd: sleepEnd,
                        unifiedSegments: unifiedSegments,
                        sleepGoalMinutes: 420 // Default to 7 hours (420 minutes), could be configurable
                    )

                    debugPrint("Using Polar-style calculation for sleep score: \(totalScore) from \(sleepStart) to \(sleepEnd)")

                    // Determine the source based on available data
                    let source: CTMetricSource = {
                        // Check if we have Polar sleep data in the repository
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                        let polarSleepData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                                      + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                                      + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                        return !polarSleepData.isEmpty ? .polar360 : .appleHealth
                    }()
                    debugPrint("Calculated sleep score: \(totalScore) from \(source.rawValue)")
                    onSleepScoreDidUpdate?(SleepScoreTile(score: totalScore, date: latestNight.date, source: source))
                    return
                }
            } else {
                // Alternative: Get all sleep segments for this night to calculate raw time from the metrics repo
                let allSegments = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)

                if !allSegments.isEmpty {
                    let sleepStart = allSegments.min { $0.date < $1.date }?.date ?? Date()
                    let sleepEnd = allSegments.max { $0.date < $1.date }?.date ?? Date()
                    totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

                    // Only proceed if we have a valid sleep time
                    if totalSleepTime > 0 {
                        // Calculate sleep score using Polar-style algorithm
                        let totalScore = calculatePolarStyleSleepScore(
                            sleepStart: sleepStart,
                            sleepEnd: sleepEnd,
                            unifiedSegments: [], // No detailed segments available here
                            sleepGoalMinutes: 420 // Default to 7 hours (420 minutes), could be configurable
                        )

                        debugPrint("Using Polar-style calculation for sleep score: \(totalScore) from \(sleepStart) to \(sleepEnd)")

                        // Determine the source based on available data
                        let source: CTMetricSource = {
                            // Check if we have Polar sleep data in the repository
                            let cal = Calendar.current
                            let today = cal.startOfDay(for: Date())
                            let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                            let polarSleepData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                                          + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                                          + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                            return !polarSleepData.isEmpty ? .polar360 : .appleHealth
                        }()
                        debugPrint("Calculated sleep score: \(totalScore) from \(source.rawValue)")
                        onSleepScoreDidUpdate?(SleepScoreTile(score: totalScore, date: latestNight.date, source: source))
                        return
                    }
                } else {
                    // Fallback to the original calculation if no segments found
                    if latestNight.hours > 0 {
                        totalSleepTime = latestNight.hours
                        // print("Found sleep repository data: \(latestNight.hours) hours at \(latestNight.date)")
                        // Calculate a simple sleep score based on hours slept
                        // Calculate sleep score using Polar-style algorithm
                        // We have the sleep hours from latestNight but need to estimate start/end times
                        let estimatedSleepEnd = Date()
                        let estimatedSleepStart = estimatedSleepEnd.addingTimeInterval(-(totalSleepTime * 3600)) // Convert hours to seconds
                        let totalScore = calculatePolarStyleSleepScore(
                            sleepStart: estimatedSleepStart,
                            sleepEnd: estimatedSleepEnd,
                            unifiedSegments: [], // No detailed segments available here
                            sleepGoalMinutes: 420 // Default to 7 hours (420 minutes), could be configurable
                        )

                        // Determine the source based on available data
                        let source: CTMetricSource = {
                            // Check if we have Polar sleep data in the repository
                            let cal = Calendar.current
                            let today = cal.startOfDay(for: Date())
                            let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                            let polarSleepData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                                          + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                                          + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                            return !polarSleepData.isEmpty ? .polar360 : .appleHealth
                        }()
                        debugPrint("Calculated sleep score: \(totalScore) from \(source.rawValue)")
                        onSleepScoreDidUpdate?(SleepScoreTile(score: totalScore, date: latestNight.date, source: source))
                        return
                    }
                }
            }
        }
        // print("No sleep repository data found or hours <= 0")

        // Fallback: Derive from repo sleep segments mirrored from Apple Health
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let asleep = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                  + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                  + repo.series(kind: .sleepREM,  from: today, to: tomorrow, source: .polar360)
        let awake = repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)

        debugPrint("Polar360 Asleep segments count: \(asleep.count)")
        debugPrint("Polar360 Awake segments count: \(awake.count)")

        guard !asleep.isEmpty else {
            // print("No asleep segments found, checking hub for sleep data...")

            // If no sleep data from repositories, try to create a sleep score from hub data
            if let hubProps = lastCalmProps, hubProps.trend.sleepHours > 0 {
                // Calculate a simple sleep score based on the sleep hours from hub
                let hubSleepHours = hubProps.trend.sleepHours
                let durationScore = min(50, Int((hubSleepHours / 8.0) * 50)) // Up to 50 points for duration
                let qualityScore = 25 // Base quality score
                let consistencyScore = 25 // Base consistency score
                let totalScore = min(100, durationScore + qualityScore + consistencyScore)

                // print("Creating sleep score from hub data: \(totalScore) based on \(hubSleepHours) hours")
                onSleepScoreDidUpdate?(SleepScoreTile(score: totalScore, date: Date(), source: .polar360))
            } else {
                // print("No sleep data available anywhere, sending nil")
                onSleepScoreDidUpdate?(nil)
            }
            return
        }

        // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
        if !asleep.isEmpty {
            // Get the earliest start time and latest end time from all segments
            let allSegments = asleep + repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .polar360)
            let sleepStart = allSegments.min { $0.date < $1.date }?.date ?? Date()
            let sleepEnd = allSegments.max { $0.date < $1.date }?.date ?? Date()
            let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours

            let durationPart = min(50.0, (totalSleepTime / 8.0) * 50.0)
            let startTimes = asleep.map { $0.date }.sorted()
            let bedtimeDeviation = (startTimes.last!.timeIntervalSince(startTimes.first!) / 3600.0)
            let bedtimePart = max(0.0, 30.0 - (bedtimeDeviation * 3.0))
            let interruptions = awake.count
            let interruptionPart = max(0.0, 20.0 - Double(interruptions) * 2.0)
            let score = Int(round(durationPart + bedtimePart + interruptionPart))
            let nightEnd = (asleep.last?.date ?? Date())

            debugPrint("Calculated sleep score from Polar360 segments: \(score) with \(totalSleepTime) hours (raw calculation from \(sleepStart) to \(sleepEnd))")
            onSleepScoreDidUpdate?(SleepScoreTile(score: score, date: nightEnd, source: .polar360))
        } else {
            debugPrint("No sleep segments found, sending nil")
            onSleepScoreDidUpdate?(nil)
        }
    }

    // MARK: - Utils
    private func formatTimeStamp(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "h:mm:ss a"; return f.string(from: date) }
    private func formatFullTimestamp(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "M/d/yyyy h:mm:ss a"; return f.string(from: date) }
    private func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "d MMM"; return f.string(from: date) }
    private func formatHours(_ hours: Double) -> String { let h = Int(hours); let m = Int((hours - Double(h)) * 60.0); return "\(h)hr \(m)min" }

    private func windowForLastNight(anchoredAt now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let noon     = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!
        let start6pm = cal.date(byAdding: .hour, value: -18, to: noon)!
        return (start6pm, noon)
    }

    private func latestNightBefore(date: Date) -> (date: Date, hours: Double)? {
        // We look 48h back from the anchor
        let start = date.addingTimeInterval(-48 * 3600)
        let segs = SleepRepository.shared.unifiedSegments(from: start, to: date)
        guard let last = segs.last else { return nil }

        let bucket = SleepRepository.shared.sleepDayStart(for: last.start)
        let nextBucket = bucket.addingTimeInterval(24 * 3600)

        let nightSegs = SleepRepository.shared.unifiedSegments(from: bucket, to: nextBucket)

        // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
        if !nightSegs.isEmpty {
            let sleepStart = nightSegs.min { $0.start < $1.start }?.start ?? Date()
            let sleepEnd = nightSegs.max { $0.end < $1.end }?.end ?? Date()
            let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
            return (bucket, totalSleepTime)
        } else {
            // Fallback to the original calculation if no segments found
            let secs = nightSegs.reduce(0) {
                $0 + max(0, $1.end.timeIntervalSince($1.start))
            }
            return (bucket, secs / 3600.0)
        }
    }

    // MARK: - App Lifecycle Methods
    func handleAppWillEnterForeground() {
        // Force refresh when app returns from background
        scheduleFullRefresh(force: true)

        // Reconnect to Polar if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PolarManager.shared.resumeAutoReconnectOnForeground()
        }

        // Refresh sleep data after connection is established
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self._refreshSleepScore()
        }
    }

    func handleAppDidBecomeActive() {
        // Restart live updates
        startLiveUpdates()

        // Schedule a refresh after a short delay to allow connections to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scheduleFullRefresh()
        }

        // Refresh sleep data as well
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self._refreshSleepScore()
        }
    }

    // MARK: - Polar-Style Sleep Score Calculation
    private func calculatePolarStyleSleepScore(
        sleepStart: Date,
        sleepEnd: Date,
        unifiedSegments: [SleepSegment],
        sleepGoalMinutes: Int
    ) -> Int {
        // Calculate total time in bed
        let timeInBed = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // in hours
        
        // If no detailed segments, use basic calculation
        if unifiedSegments.isEmpty {
            let actualSleepHours = timeInBed
            let sleepGoalHours = Double(sleepGoalMinutes) / 60.0
            
            // Calculate sleep amount score based on ratio to goal
            let sleepRatio = actualSleepHours / sleepGoalHours
            let sleepAmountScore: Int
            if sleepRatio >= 1.0 {
                sleepAmountScore = 100
            } else if sleepRatio >= 0.9 {
                sleepAmountScore = 90
            } else if sleepRatio >= 0.8 {
                sleepAmountScore = 80
            } else if sleepRatio >= 0.7 {
                sleepAmountScore = 65
            } else {
                sleepAmountScore = 50
            }
            
            // Apply hard caps based on actual sleep time
            if actualSleepHours < 5.0 {
                return min(sleepAmountScore, 60)
            } else if actualSleepHours < 6.0 {
                return min(sleepAmountScore, 70)
            }
            
            return sleepAmountScore
        }
        
        // Detailed calculation with sleep segments
        var lightSleep: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var awakeTime: TimeInterval = 0
        
        // Calculate duration for each sleep stage
        for segment in unifiedSegments {
            let duration = segment.end.timeIntervalSince(segment.start)
            switch segment.stage {
            case .core:  // In the app's context, "core" represents light sleep
                lightSleep += duration
            case .deep:
                deepSleep += duration
            case .rem:
                remSleep += duration
            case .awake:
                awakeTime += duration
            }
        }
        
        let actualSleep = lightSleep + deepSleep + remSleep
        let actualSleepHours = actualSleep / 3600.0
        let timeInBedHours = timeInBed
        
        // 4. Sleep Amount Score (0-100)
        let sleepGoalSeconds = Double(sleepGoalMinutes) * 60.0
        let sleepRatio = actualSleep / sleepGoalSeconds
        
        let sleepAmountScore: Int
        if sleepRatio >= 1.0 {
            sleepAmountScore = 100
        } else if sleepRatio >= 0.9 {
            sleepAmountScore = 90
        } else if sleepRatio >= 0.8 {
            sleepAmountScore = 80
        } else if sleepRatio >= 0.7 {
            sleepAmountScore = 65
        } else {
            sleepAmountScore = 50
        }
        
        // 5. Interruptions & Solidity
        let actualSleepPercent = (actualSleep / (timeInBed * 3600.0)) * 100.0
        
        // Count wake segments and long interruptions
        let wakeSegments = unifiedSegments.filter { $0.stage == .awake }
        let longInterruptions = wakeSegments.filter { ($0.end.timeIntervalSince($0.start) / 60.0) >= 1.0 } // 1+ minute interruptions
        let longInterruptionTime = longInterruptions.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let longInterruptionPercent = (longInterruptionTime / (timeInBed * 3600.0)) * 100.0
        
        let solidityScore: Int
        if longInterruptionPercent < 3.0 {
            solidityScore = 90
        } else if longInterruptionPercent < 6.0 {
            solidityScore = 75
        } else if longInterruptionPercent < 10.0 {
            solidityScore = 60
        } else {
            solidityScore = 45
        }
        
        // 6. Continuity Score (0-5)
        let wakeCount = Double(wakeSegments.count)
        let continuityScore = max(0.0, min(5.0, 5.0 - (wakeCount * 0.15) - (Double(longInterruptions.count) * 0.25)))
        
        // 7. Regeneration Score (0-100)
        let deepRatio = deepSleep / actualSleep
        let remRatio = remSleep / actualSleep
        
        let deepScore: Int
        if deepRatio >= 0.20 && deepRatio <= 0.25 {
            deepScore = 100
        } else if (deepRatio >= 0.15 && deepRatio < 0.20) || (deepRatio > 0.25 && deepRatio < 0.30) {
            deepScore = 85
        } else {
            deepScore = 65
        }
        
        let remScore: Int
        if remRatio >= 0.17 && remRatio <= 0.25 {
            remScore = 100
        } else if (remRatio >= 0.12 && remRatio < 0.17) || (remRatio > 0.25 && remRatio < 0.30) {
            remScore = 80
        } else {
            remScore = 60
        }
        
        let regenerationScore = Int(Double(deepScore) * 0.6 + Double(remScore) * 0.4)
        
        // 9. Final Sleep Score (0-100) - Weighted Sum
        let weightedScore = Double(sleepAmountScore) * 0.35 +
                           Double(solidityScore) * 0.20 +
                           (continuityScore / 5.0) * 100.0 * 0.20 +
                           Double(regenerationScore) * 0.20 +
                           actualSleepPercent * 0.05
        
        var finalScore = Int(weightedScore)
        
        // 10. Hard Caps
        if actualSleepHours < 5.0 {
            finalScore = min(finalScore, 60)
        } else if actualSleepHours < 6.0 {
            finalScore = min(finalScore, 70)
        }
        
        // Clamp final score between 0 and 100
        return max(0, min(100, finalScore))
    }
}

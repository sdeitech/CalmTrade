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

            let todaySleep = SleepRepository.shared.latestNight()?.hours

            // Previous-night unified sleep
            let prevAnchor = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
            let prevNight = self.latestNightBefore(date: prevAnchor)?.hours

            let sleepIsUp: Bool = {
                guard let cur = todaySleep, let prev = prevNight else {
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
        if let h = chosenSleepHours {
            data.sleepTotal = formatHours(h)

            if let night = SleepRepository.shared.latestNight() {
                data.sleepDate = formatDate(night.date)
            }
        } else {
            // If no chosen sleep hours, try to get from repository
            if let latestNight = SleepRepository.shared.latestNight() {
                data.sleepTotal = formatHours(latestNight.hours)
                data.sleepDate = formatDate(latestNight.date)
            } else {
                // Try to get from repo series as fallback
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

                // Check for Polar sleep data specifically
                let polarSleepData = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .polar360)
                              + repo.series(kind: .sleepREM, from: today, to: tomorrow, source: .polar360)

                if !polarSleepData.isEmpty {
                    let totalPolarHours = polarSleepData.reduce(0.0) { $0 + $1.value } / 3600.0
                    data.sleepTotal = formatHours(totalPolarHours)
                    data.sleepDate = formatDate(today)
                }
            }
        }


        // Steps (today + 7-day avg)
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

        let updatedTrend = TrendData(
            hrvMs: base.trend.hrvMs,
            hrvIsUp: base.trend.hrvIsUp,
            hrBpm: base.trend.hrBpm,
            hrIsDown: base.trend.hrIsDown,
            sleepHours: hours ?? 0,
            sleepIsUp: isUp
        )

        let newProps = CalmScoreTileProps(
            score: base.score,
            lastUpdate: Date(),
            deviceSource: base.deviceSource,
            isStreaming: base.isStreaming,
            trend: updatedTrend
        )

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

    // MARK: - Sleep Score logic (updated to include Polar sleep data)
    @objc private func _refreshSleepScore() {
        // Prefer explicit numeric Sleep Score if available
        if let v = [repo.latestValue(kind: .sleepScore, source: .appleHealth),
                    repo.latestValue(kind: .sleepScore, source: .polar360)]
            .compactMap({ $0 }).max(by: { $0.date < $1.date }) {
            onSleepScoreDidUpdate?(SleepScoreTile(score: Int(v.value.rounded()), date: v.date, source: v.source))
            return
        }

        // First, try to get sleep hours from SleepRepository (which should include Polar data)
        if let latestNight = SleepRepository.shared.latestNight(),
           latestNight.hours > 0 {
            // Calculate a simple sleep score based on hours slept
            let durationScore = min(50, Int((latestNight.hours / 8.0) * 50)) // Up to 50 points for duration
            let qualityScore = 25 // Base quality score
            let consistencyScore = 25 // Base consistency score
            let totalScore = min(100, durationScore + qualityScore + consistencyScore)

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
            onSleepScoreDidUpdate?(SleepScoreTile(score: totalScore, date: latestNight.date, source: source))
            return
        }

        // Fallback: Derive from repo sleep segments mirrored from Apple Health
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let asleep = repo.series(kind: .sleepCore, from: today, to: tomorrow, source: .appleHealth)
                  + repo.series(kind: .sleepDeep, from: today, to: tomorrow, source: .appleHealth)
                  + repo.series(kind: .sleepREM,  from: today, to: tomorrow, source: .appleHealth)
        let awake = repo.series(kind: .sleepAwake, from: today, to: tomorrow, source: .appleHealth)

        guard !asleep.isEmpty else {
            onSleepScoreDidUpdate?(nil); return
        }

        let totalHours = asleep.reduce(0.0) { $0 + $1.value } / 3600.0
        let durationPart = min(50.0, (totalHours / 8.0) * 50.0)
        let startTimes = asleep.map { $0.date }.sorted()
        let bedtimeDeviation = (startTimes.last!.timeIntervalSince(startTimes.first!) / 3600.0)
        let bedtimePart = max(0.0, 30.0 - (bedtimeDeviation * 3.0))
        let interruptions = awake.count
        let interruptionPart = max(0.0, 20.0 - Double(interruptions) * 2.0)
        let score = Int(round(durationPart + bedtimePart + interruptionPart))
        let nightEnd = (asleep.last?.date ?? Date())

        onSleepScoreDidUpdate?(SleepScoreTile(score: score, date: nightEnd, source: .appleHealth))
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
        let secs = nightSegs.reduce(0) {
            $0 + max(0, $1.end.timeIntervalSince($1.start))
        }
        return (bucket, secs / 3600.0)
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

}

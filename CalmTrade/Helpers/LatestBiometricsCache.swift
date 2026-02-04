//
//  LatestBiometricsCache.swift
//  CalmTrade
//
//  Per-user local cache for last-known biometrics (HR, RMSSD, SDNN, RHR, Sleep).
//  Source of truth: CTMetricsRepository (user-scoped).
//  Provides lightweight persisted cache for warm starts.
//

import Foundation

final class LatestBiometricsCache {
    static let shared = LatestBiometricsCache()

    // Persisted record
    private struct Record: Codable { let value: Double; let date: Date }
    private enum Key: String, CaseIterable { case hr, rmssd, sdnn, rhr, sleep }

    private let io = DispatchQueue(label: "ct.latestmetrics.cache", attributes: .concurrent)
    private var store: [String: Record] = [:]
    private var url: URL { cacheURL(for: SessionManager.shared.current?.id) }

    // MARK: - Init
    private init() {
        loadStore()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserChanged),
            name: .userAccountDidChange,
            object: nil
        )
    }

    // MARK: - File management
    private func cacheURL(for userId: String?) -> URL {
        let id = userId ?? "_anonymous"
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Users/\(id)/Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("latest_biometrics.json")
    }

    private func loadStore() {
        io.async(flags: .barrier) {
            if let data = try? Data(contentsOf: self.url),
               let dict = try? JSONDecoder().decode([String: Record].self, from: data) {
                self.store = dict
            } else {
                self.store = [:]
            }
        }
    }

    @objc private func onUserChanged() {
        loadStore()
        refreshLatestSleepAsync()
    }

    // MARK: - Persist helpers
    private func persist() {
        io.async(flags: .barrier) {
            guard let data = try? JSONEncoder().encode(self.store) else { return }
            try? data.write(to: self.url, options: .atomic)
        }
    }

    private func set(_ k: Key, value: Double, date: Date = Date()) {
        io.async(flags: .barrier) {
            self.store[k.rawValue] = Record(value: value, date: date)
            self.persist()
        }
    }

    private func get(_ k: Key) -> Double? {
        var result: Double?
        io.sync { result = store[k.rawValue]?.value }
        return result
    }

    // MARK: - Repo-first snapshot (always current)
    func snapshot() -> CalmScoreBiometricInputs {
        let repo = CTMetricsRepository.shared

        let heartRate = repo.latestValue(kind: .heartRate)?.value
        let hrvInRmssd = repo.latestValue(kind: .rmssd)?.value
        let hrvInSdnn = repo.latestValue(kind: .sdnn)?.value
        let restingHeartRate = repo.latestValue(kind: .restingHeartRate)?.value

        // Calculate sleep duration from SleepRepository instead of relying on .sleepHours metric
        var sleepDurationInHours: Double?
        if let latestNight = SleepRepository.shared.latestNight() {
            // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
            if !latestNight.segments.isEmpty {
                let sleepStart = latestNight.segments.min { $0.start < $1.start }?.start ?? Date()
                let sleepEnd = latestNight.segments.max { $0.end < $1.end }?.end ?? Date()
                let totalSleepTime = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
                sleepDurationInHours = totalSleepTime
            } else {
                // Fallback to the stored hours if no segments available
                sleepDurationInHours = latestNight.hours
            }
        } else {
            // Fallback to the repository's sleepHours metric if no sleep night available
            sleepDurationInHours = repo.latestValue(kind: .sleepHours)?.value
        }

        debugPrint("=== LatestBiometricsCache Snapshot ===")
        debugPrint("Heart Rate: \(String(describing: heartRate))")
        debugPrint("RMSSD: \(String(describing: hrvInRmssd))")
        debugPrint("SDNN: \(String(describing: hrvInSdnn))")
        debugPrint("Resting Heart Rate: \(String(describing: restingHeartRate))")
        debugPrint("Sleep Duration (Hours): \(String(describing: sleepDurationInHours))")
        debugPrint("=====================================")

        return CalmScoreBiometricInputs(
            heartRate:            heartRate,
            hrvInRmssd:           hrvInRmssd,
            hrvInSdnn:            hrvInSdnn,
            restingHeartRate:     restingHeartRate,
            sleepDurationInHours: sleepDurationInHours
        )
    }


    // MARK: - Cache update / read APIs
    func update(from bundle: CalmScoreBiometricInputs) {
        let now = Date()

        if let v = bundle.heartRate        { set(.hr,    value: v, date: now) }
        if let v = bundle.hrvInRmssd       { set(.rmssd, value: v, date: now) }
        if let v = bundle.hrvInSdnn        { set(.sdnn,  value: v, date: now) }
        if let v = bundle.restingHeartRate {
            set(.rhr,   value: v, date: now)
            debugPrint("=== LatestBiometricsCache Update ===")
            debugPrint("Resting Heart Rate updated: \(v)")
            debugPrint("===================================")
        }

        // Sleep is not taken from the bundle anymore.
        // Always recompute + write unified full-night sleep.
        refreshLatestSleepAsync()
    }
    
    func refreshLatestSleepAsync() {
        DispatchQueue.global(qos: .utility).async {
            guard let night = SleepRepository.shared.latestNight() else {
                debugPrint("=== LatestBiometricsCache Sleep Refresh ===")
                debugPrint("No sleep night data available")
                debugPrint("=========================================")
                return
            }

            // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
            var sleepHours: Double
            if !night.segments.isEmpty {
                let sleepStart = night.segments.min { $0.start < $1.start }?.start ?? Date()
                let sleepEnd = night.segments.max { $0.end < $1.end }?.end ?? Date()
                sleepHours = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
            } else {
                // Fallback to the stored hours if no segments available
                sleepHours = night.hours
            }

            debugPrint("=== LatestBiometricsCache Sleep Refresh ===")
            debugPrint("Sleep night date: \(night.date)")
            debugPrint("Original hours: \(night.hours)")
            debugPrint("Raw calculation hours: \(sleepHours)")
            debugPrint("Sleep segments count: \(night.segments.count)")
            for (index, segment) in night.segments.enumerated() {
                debugPrint("  Segment \(index): \(segment.stage) from \(segment.start) to \(segment.end) (source: \(segment.source))")
            }
            debugPrint("=========================================")

            self.io.async(flags: .barrier) {
                self.store[Key.sleep.rawValue] = Record(value: sleepHours, date: night.date)
                self.persist()
            }
        }
    }

    func composeInputsFromCache() -> CalmScoreBiometricInputs {
        // For sleep, we should recalculate using raw calculation instead of using cached value
        var cachedSleepHours: Double?
        if let latestNight = SleepRepository.shared.latestNight() {
            // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
            if !latestNight.segments.isEmpty {
                let sleepStart = latestNight.segments.min { $0.start < $1.start }?.start ?? Date()
                let sleepEnd = latestNight.segments.max { $0.end < $1.end }?.end ?? Date()
                cachedSleepHours = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
            } else {
                // Fallback to the stored hours if no segments available
                cachedSleepHours = latestNight.hours
            }
        } else {
            // Fallback to the cached value if no sleep night available
            cachedSleepHours = get(.sleep)
        }

        return CalmScoreBiometricInputs(
            heartRate:            get(.hr),
            hrvInRmssd:           get(.rmssd),
            hrvInSdnn:            get(.sdnn),
            restingHeartRate:     get(.rhr),
            sleepDurationInHours: cachedSleepHours
        )
    }

    func fillingMissing(from bundle: CalmScoreBiometricInputs) -> CalmScoreBiometricInputs {
        let cached = composeInputsFromCache()
        return CalmScoreBiometricInputs(
            heartRate:            bundle.heartRate            ?? cached.heartRate,
            hrvInRmssd:           bundle.hrvInRmssd           ?? cached.hrvInRmssd,
            hrvInSdnn:            bundle.hrvInSdnn            ?? cached.hrvInSdnn,
            restingHeartRate:     bundle.restingHeartRate     ?? cached.restingHeartRate,
            sleepDurationInHours: bundle.sleepDurationInHours ?? cached.sleepDurationInHours
        )
    }
}

extension LatestBiometricsCache {

    /// Compute latest full-night sleep based on unified repository data.
    /// Stores the NIGHT'S TOTAL (not last fragment).
    func refreshLatestSleep() {
        DispatchQueue.global(qos: .utility).async {
            guard let night = SleepRepository.shared.latestNight() else {
                debugPrint("=== LatestBiometricsCache Manual Sleep Refresh ===")
                debugPrint("No sleep night data available")
                debugPrint("===============================================")
                return
            }

            // Calculate raw sleep time from sleep start to end (to match Polar's calculation)
            var sleepHours: Double
            if !night.segments.isEmpty {
                let sleepStart = night.segments.min { $0.start < $1.start }?.start ?? Date()
                let sleepEnd = night.segments.max { $0.end < $1.end }?.end ?? Date()
                sleepHours = sleepEnd.timeIntervalSince(sleepStart) / 3600.0 // Convert to hours
            } else {
                // Fallback to the stored hours if no segments available
                sleepHours = night.hours
            }

            debugPrint("=== LatestBiometricsCache Manual Sleep Refresh ===")
            debugPrint("Sleep night date: \(night.date)")
            debugPrint("Original hours: \(night.hours)")
            debugPrint("Raw calculation hours: \(sleepHours)")
            debugPrint("Sleep segments count: \(night.segments.count)")
            for (index, segment) in night.segments.enumerated() {
                debugPrint("  Segment \(index): \(segment.stage) from \(segment.start) to \(segment.end) (source: \(segment.source))")
            }
            debugPrint("===============================================")

            self.io.async(flags: .barrier) {
                self.store[Key.sleep.rawValue] = Record(value: sleepHours, date: night.date)
                self.persist()
            }
        }
    }

}

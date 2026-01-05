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

        return CalmScoreBiometricInputs(
            heartRate:            repo.latestValue(kind: .heartRate)?.value,
            hrvInRmssd:           repo.latestValue(kind: .rmssd)?.value,
            hrvInSdnn:            repo.latestValue(kind: .sdnn)?.value,
            restingHeartRate:     repo.latestValue(kind: .restingHeartRate)?.value,
            sleepDurationInHours: repo.latestValue(kind: .sleepHours)?.value
        )
    }


    // MARK: - Cache update / read APIs
    func update(from bundle: CalmScoreBiometricInputs) {
        let now = Date()

        if let v = bundle.heartRate        { set(.hr,    value: v, date: now) }
        if let v = bundle.hrvInRmssd       { set(.rmssd, value: v, date: now) }
        if let v = bundle.hrvInSdnn        { set(.sdnn,  value: v, date: now) }
        if let v = bundle.restingHeartRate { set(.rhr,   value: v, date: now) }

        // Sleep is not taken from the bundle anymore.
        // Always recompute + write unified full-night sleep.
        refreshLatestSleepAsync()
    }
    
    func refreshLatestSleepAsync() {
        DispatchQueue.global(qos: .utility).async {
            guard let night = SleepRepository.shared.latestNight() else { return }
            self.io.async(flags: .barrier) {
                self.store[Key.sleep.rawValue] = Record(value: night.hours, date: night.date)
                self.persist()
            }
        }
    }

    func composeInputsFromCache() -> CalmScoreBiometricInputs {
        CalmScoreBiometricInputs(
            heartRate:            get(.hr),
            hrvInRmssd:           get(.rmssd),
            hrvInSdnn:            get(.sdnn),
            restingHeartRate:     get(.rhr),
            sleepDurationInHours: get(.sleep)
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
            guard let night = SleepRepository.shared.latestNight() else { return }
            let hours = night.hours

            self.io.async(flags: .barrier) {
                self.store[Key.sleep.rawValue] = Record(value: hours, date: night.date)
                self.persist()
            }
        }
    }

}

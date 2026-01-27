//
//  HealthKitService.swift
//  CalmTrade
//
//  READ-ONLY HealthKit service with background mirroring to CTMetricsRepository.
//  Now per-user aware (anchors & repo scoped by SessionManager.shared.current?.id).
//

import Foundation
import HealthKit

public final class HealthKitService {
    public static let shared = HealthKitService()
    public let healthStore = HKHealthStore()
    private init() {}

    // MARK: - Units
    private let unitBPM = HKUnit.count().unitDivided(by: .minute())
    private let unitMs  = HKUnit.secondUnit(with: .milli)

    // MARK: - Types
    private var hrType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .heartRate)! }
    private var hrvSDNNType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)! }
    private var restingHRType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .restingHeartRate)! }
    private var stepsType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .stepCount)! }
    private var sleepType: HKCategoryType { HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)! }

    // MARK: Authorization — READ ONLY
    public func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "Health data unavailable"]))
            return
        }
        let toRead: Set<HKObjectType> = [hrType, hrvSDNNType, restingHRType, stepsType, sleepType]
        healthStore.requestAuthorization(toShare: [], read: toRead) { ok, err in completion(ok, err) }
    }

    // MARK: Background mirroring (Observer + Anchored)
    public func startBackgroundMirroring() {
        stopBackgroundMirroring() // Clean up any existing observers first

        let types: [HKSampleType] = [hrType, hrvSDNNType, restingHRType, stepsType, sleepType]
        types.forEach(registerObserver)
    }

    public func stopBackgroundMirroring() {
        // Stop all observers and background deliveries
        for (type, query) in typeToObserverMap {
            healthStore.stop(query)
            healthStore.disableBackgroundDelivery(for: type) { _, _ in }
        }
        typeToObserverMap.removeAll()
    }

    private var typeToObserverMap: [HKSampleType: HKObserverQuery] = [:]

    deinit {
        // Ensure all observers are properly cleaned up when the service is deallocated
        stopBackgroundMirroring()
    }

    private func registerObserver(for type: HKSampleType) {
        // Remove any existing observer for this type
        if let existingQuery = typeToObserverMap[type] {
            healthStore.stop(existingQuery)
            healthStore.disableBackgroundDelivery(for: type) { _, _ in }
        }

        let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            self?.pullDeltas(for: type) {
                completion()
            }
        }
        healthStore.execute(q)
        typeToObserverMap[type] = q

        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        pullDeltas(for: type, completion: {}) // initial sync
    }

    // MARK: Pull deltas from HealthKit → local repo
    private func pullDeltas(for sampleType: HKSampleType, completion: @escaping () -> Void) {
        let repo = CTMetricsRepository.shared
        let id = sampleType.identifier
        let anchor = loadAnchor(for: id)

        let q = HKAnchoredObjectQuery(type: sampleType,
                                      predicate: nil,
                                      anchor: anchor,
                                      limit: HKObjectQueryNoLimit) {
            [weak self] _, newSamples, _, newAnchor, error in
            defer {
                // Single “mirror finished” pulse
                NotificationCenter.default.post(name: .ctMetricsDidMirror, object: nil)
                completion()
            }
            guard error == nil, let self else { return }

            if let newAnchor { self.saveAnchor(newAnchor, for: id) }

            switch sampleType {
            case is HKQuantityType:
                let qtySamples = (newSamples as? [HKQuantitySample]) ?? []
                for s in qtySamples {
                    if s.quantityType == self.hrType {
                        repo.upsert(kind: .heartRate,
                                    value: s.quantity.doubleValue(for: self.unitBPM),
                                    unit: "bpm", source: .appleHealth, date: s.endDate)
                    } else if s.quantityType == self.hrvSDNNType {
                        repo.upsert(kind: .sdnn,
                                    value: s.quantity.doubleValue(for: self.unitMs),
                                    unit: "ms", source: .appleHealth, date: s.endDate)
                    } else if s.quantityType == self.restingHRType {
                        repo.upsert(kind: .restingHeartRate,
                                    value: s.quantity.doubleValue(for: self.unitBPM),
                                    unit: "bpm", source: .appleHealth, date: s.endDate)
                    } else if s.quantityType == self.stepsType {
                        repo.upsert(kind: .steps,
                                    value: s.quantity.doubleValue(for: .count()),
                                    unit: "count", source: .appleHealth, date: s.endDate)
                    }
                }

            case is HKCategoryType:
                let catSamples = (newSamples as? [HKCategorySample]) ?? []

                // Per-stage segments
                for s in catSamples where s.categoryType == self.sleepType {
                    let duration = s.endDate.timeIntervalSince(s.startDate)
                    guard duration > 0 else { continue }

                    if #available(iOS 16.0, *) {
                        guard let v = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
                        let kind: CTMetricKind?
                        switch v {
                        case .awake:         kind = .sleepAwake
                        case .asleepREM:     kind = .sleepREM
                        case .asleepCore:    kind = .sleepCore
                        case .asleepDeep:    kind = .sleepDeep
                        case .inBed, .asleepUnspecified: kind = nil
                        @unknown default: kind = nil
                        }
                        if let k = kind {
                            repo.upsert(kind: k, value: duration, unit: "s",
                                        source: .appleHealth, date: s.startDate)
                        }
                    } else {
                        if s.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                            repo.upsert(kind: .sleepCore, value: duration, unit: "s",
                                        source: .appleHealth, date: s.startDate)
                        } else if s.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                            repo.upsert(kind: .sleepAwake, value: duration, unit: "s",
                                        source: .appleHealth, date: s.startDate)
                        }
                    }
                }

                // Nightly rollup (.sleepHours)
                let asleepSegments: [(Date, Date)] = catSamples
                    .filter { $0.categoryType == self.sleepType }
                    .compactMap { s in
                        if #available(iOS 16.0, *) {
                            let v = HKCategoryValueSleepAnalysis(rawValue: s.value)
                            let isAsleep = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM].contains(v)
                            return isAsleep ? (s.startDate, s.endDate) : nil
                        } else {
                            return (s.value == HKCategoryValueSleepAnalysis.asleep.rawValue)
                                   ? (s.startDate, s.endDate) : nil
                        }
                    }

                for (nightEnd, hours) in self.rollupSleepToNights(segments: asleepSegments) {
                    repo.upsert(kind: .sleepHours, value: hours, unit: "h",
                                source: .appleHealth, date: nightEnd)
                }

            default:
                break
            }
        }
        healthStore.execute(q)
    }

    // MARK: Sleep nightly rollup
    func rollupSleepToNights(segments: [(Date, Date)]) -> [(Date, Double)] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []
        for (s, e) in sorted {
            guard s < e else { continue }
            if var last = merged.last, s <= last.1 {
                merged.removeLast()
                merged.append((last.0, max(last.1, e)))
            } else {
                merged.append((s, e))
            }
        }

        let cal = Calendar.current
        func nightEndNoon(for date: Date) -> Date {
            let dayStart = cal.startOfDay(for: date)
            return cal.date(byAdding: .hour, value: 12, to: dayStart)!
        }

        var buckets: [Date: TimeInterval] = [:]
        for (s, e) in merged {
            var cur = s
            while cur < e {
                let nightEnd = nightEndNoon(for: cur)
                let nightStart = cal.date(byAdding: .hour, value: -18, to: nightEnd)!
                let thisEnd = min(e, nightEnd)
                let clippedStart = max(cur, nightStart)
                if clippedStart < thisEnd {
                    buckets[nightEnd, default: 0] += thisEnd.timeIntervalSince(clippedStart)
                }
                cur = thisEnd
            }
        }

        return buckets.map { ($0.key, $0.value / 3600.0) }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: Anchors persistence — per-user
    private func loadAnchor(for id: String) -> HKQueryAnchor? {
        let userId = SessionManager.shared.current?.id ?? "_anonymous"
        let key = "ct.hk.\(userId).anchor.\(id)"
        guard let data = UserScope.defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ a: HKQueryAnchor?, for id: String) {
        guard let a else { return }
        let userId = SessionManager.shared.current?.id ?? "_anonymous"
        let key = "ct.hk.\(userId).anchor.\(id)"
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: a, requiringSecureCoding: true) {
            UserScope.defaults.set(data, forKey: key)
        }
    }
}

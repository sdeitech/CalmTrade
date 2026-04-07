//
//  DeviceManager.swift
//  CalmTrade
//
//  READS from HealthKit (background mirror only),
//  WRITES to local repositories via Polar/HealthKit integrations.
//  Handles CalmScore forwarding and per-user data scoping.
//

import Foundation
import HealthKit

final class DeviceManager {

    // MARK: - Singleton
    static let shared = DeviceManager()
    private init() {
        // Observe user changes to reset any cached state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserChanged),
            name: .userAccountDidChange,
            object: nil
        )
    }

    // MARK: - Source labeling
    enum DeviceSource {
        case polarH10
        case polar360
        case appleHealthKit
    }

    var currentSource: DeviceSource = .appleHealthKit

    // MARK: - Live RMSSD / SDNN cache (for smoothing / UI hints)
    private struct LiveRMSSD { let valueMs: Double; let timestamp: Date }
    private struct LiveSDNN { let valueMs: Double; let timestamp: Date }
    private var liveRMSSD: LiveRMSSD?
    private var liveSDNN: LiveSDNN?
    let liveTTL: TimeInterval = 10 // seconds

    func updateLiveRMSSD(_ rmssdMs: Double, _ sdnnMs: Double) {
        liveRMSSD = .init(valueMs: rmssdMs, timestamp: Date())
        liveSDNN = .init(valueMs: sdnnMs, timestamp: Date())
        DebugLog.shared.log("Live RMSSD: \(Int(rmssdMs)) ms, SDNN: \(Int(sdnnMs)) ms (ttl=\(Int(liveTTL))s)")
    }

    func currentLiveRMSSD() -> (value: Double, timestamp: Date)? {
        guard let live = liveRMSSD,
              Date().timeIntervalSince(live.timestamp) <= liveTTL else { return nil }
        return (live.valueMs, live.timestamp)
    }

    func currentLiveSDNN() -> (value: Double, timestamp: Date)? {
        guard let live = liveSDNN,
              Date().timeIntervalSince(live.timestamp) <= liveTTL else { return nil }
        return (live.valueMs, live.timestamp)
    }

    // MARK: - Repositories
    /// Returns the CTMetricsRepository for the current user.
    private var metricsRepo: CTMetricsRepository {
        // Each user automatically has a scoped repository via the CoreData stack.
        CTMetricsRepository.shared
    }

    // MARK: - Local repo helpers for UI/Charts
    func latestFromRepo(kind: CTMetricKind, source: CTMetricSource? = nil) -> Double? {
        metricsRepo.latestValue(kind: kind, source: source)?.value
    }

    func seriesFromRepo(kind: CTMetricKind, from: Date, to: Date, source: CTMetricSource? = nil) -> [(Date, Double)] {
        metricsRepo.seriesValues(kind: kind, from: from, to: to, source: source)
            .map { ($0.date, $0.value) }
    }

    // MARK: - CalmScore forwarding (via CalmScoreHub)
    var onLiveCalmScoreUpdate: ((CalmScoreSession) -> Void)?

    func startLiveCalmScoreUpdates(
        for phase: CalmScorePhase,
        initialDataHandler: @escaping (CalmScoreBiometricInputs) -> Void
    ) {
        // Initial snapshot for prefill
        let initial = LatestBiometricsCache.shared.snapshot()
        initialDataHandler(initial)

        // Observe new CalmScore computations
        CalmScoreHub.shared.onScore = { [weak self] session in
            guard let self else { return }
            if Thread.isMainThread {
                self.onLiveCalmScoreUpdate?(session)
            } else {
                DispatchQueue.main.async {
                    self.onLiveCalmScoreUpdate?(session)
                }
            }
        }

        CalmScoreHub.shared.start(phase: phase)
    }

    // MARK: - App bootstrap
    /// Call once on app launch (AppDelegate/SceneDelegate) to enable background syncs.
    func configureOnLaunch() {
        // HealthKit: read-only + background delivery
        HealthKitService.shared.requestAuthorization { ok, _ in
            guard ok else {
                DebugLog.shared.log("HealthKit authorization denied")
                return
            }
            HealthKitService.shared.startBackgroundMirroring()
        }

        // Polar: attach live routing → local store; enable auto reconnect
        LiveDataRouter.shared.attachToPolar(.shared)
        PolarManager.shared.enableAutoReconnectOnLaunch()
    }

    // MARK: - Legacy HealthKit wrappers
    func fetchStatisticsCollection(for quantityType: HKQuantityType,
                                   predicate: NSPredicate?,
                                   options: HKStatisticsOptions,
                                   anchorDate: Date,
                                   interval: DateComponents,
                                   completion: @escaping (HKStatisticsCollection?) -> Void)
    {
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: options,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, results, _ in completion(results) }
        HealthKitService.shared.healthStore.execute(query)
    }

    func fetchMostRecentSample<T: HKSample>(for sampleType: HKSampleType,
                                            completion: @escaping (T?) -> Void)
    {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: sampleType,
                              predicate: nil,
                              limit: 1,
                              sortDescriptors: [sort]) { _, samples, _ in
            completion(samples?.first as? T)
        }
        HealthKitService.shared.healthStore.execute(q)
    }

    // MARK: - RMSSD Preference (live > HealthKit)
    private func preferredRMSSD(hkRmssd: Double?) -> Double? {
        if let live = liveRMSSD, Date().timeIntervalSince(live.timestamp) <= liveTTL {
            return live.valueMs
        }
        return hkRmssd
    }

    // MARK: - User switch handling
    @objc private func onUserChanged() {
        liveRMSSD = nil
        liveSDNN = nil
        DebugLog.shared.log("DeviceManager: user switched → cleared transient state.")
    }
}

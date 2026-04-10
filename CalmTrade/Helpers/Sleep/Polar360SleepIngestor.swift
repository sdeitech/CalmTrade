//
//  Polar360SleepIngestor.swift
//  CalmTrade
//
//  Created by Anas Parekh on 20/11/25.
//  Direct Polar 360 sleep ingestion → SleepSegmentEntity (Core Data).
//  Option 1: run automatically on app launch / when device is connected.
//

import Foundation
import CoreData

/// Abstracts "fetch Polar sleep samples" so we don't hard-wire to one SDK flavor.
/// You will plug this into PolarBleSdk / PolarManager.
protocol Polar360SleepSource {
    /// Fetch sleep segments for [from, to) for this device, already mapped into SleepSegment.
    ///
    /// - Important: `completion` must be called on *any* queue, but exactly once.
    func fetchSleepSegments(
        deviceId: String,
        from: Date,
        to: Date,
        completion: @escaping (Swift.Result<[SleepSegment], Error>) -> Void
    )
}

/// Default no-op source so the app still builds if you forget to wire the real one.
final class NoopPolar360SleepSource: Polar360SleepSource {
    private struct NotConfiguredError: LocalizedError {
        var errorDescription: String? {
            "Polar360SleepSource is not configured. Provide a real implementation that calls PolarBleApi.getSleepData."
        }
    }

    func fetchSleepSegments(
        deviceId: String,
        from: Date,
        to: Date,
        completion: @escaping (Swift.Result<[SleepSegment], Error>) -> Void
    ) {
        completion(.failure(NotConfiguredError()))
    }
}

/// Main service that:
/// - decides when to sync,
/// - asks the Polar source for SleepSegment[],
/// - writes them into SleepSegmentEntity in Core Data,
/// - broadcasts ctSleepUpdated.
final class Polar360SleepIngestor {

    static let shared = Polar360SleepIngestor()
    
    private var source: Polar360SleepSource = NoopPolar360SleepSource()
    
    private init() {}

    /// Use the same metrics stack so SleepRepository sees the same store.
    private var bgContext: NSManagedObjectContext {
        let ctx = CTMetricsStack.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }

    /// Last-sync bookkeeping.
    private let defaults = UserDefaults.standard

    private init(source: Polar360SleepSource = NoopPolar360SleepSource()) {
        self.source = source
    }

    /// Allow AppDelegate / DI to swap in a real source at startup.
    func configure(source: Polar360SleepSource) {
        self.source = source
    }

    // MARK: - Public API (Option 1 – auto on launch / connect)

    /// Call this from AppDelegate *after* you know the primary Polar device id (or from
    /// wherever you detect "360 is connected").
    ///
    /// It will:
    /// - guard so we don't re-ingest the same night repeatedly,
    /// - fetch last 2 nights of sleep from Polar,
    /// - persist to Core Data,
    /// - fire ctSleepUpdated.
    func syncLastNightsIfNeeded(deviceId: String, nightsBack: Int = 2) {
        guard !deviceId.isEmpty else { return }

        let cal = Calendar.current
        let now = Date()

        // Yesterday 00:00
        let todayStart = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        // Fetch window: yesterday 00:00 → now
        let from = yesterdayStart
        let to = now

        NSLog("[P360Sleep] Forcing sync for device %@ window %@ → %@", deviceId, from as NSDate, to as NSDate)

        // Always ingest fresh sleep for yesterday + today
        fetchAndIngest(deviceId: deviceId, from: from, to: to)
    }

    // MARK: - Public API (Option 2 – manual fetch for specific date range)

    /// Manually fetch sleep data for a specific date range.
    /// This method can be called from UI to fetch sleep data for user-selected dates.
    ///
    /// - Parameters:
    ///   - deviceId: The Polar device ID
    ///   - from: Start date for the fetch range
    ///   - to: End date for the fetch range
    ///   - completion: Callback when the fetch is complete
    func fetchSleepDataForDateRange(
        deviceId: String,
        from: Date,
        to: Date,
        completion: @escaping (Swift.Result<String, Error>) -> Void
    ) {
        guard !deviceId.isEmpty else {
            completion(.failure(NSError(domain: "Polar360SleepIngestor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device ID is empty"])))
            return
        }

        NSLog("[P360Sleep] Manual fetch for device %@ window %@ → %@", deviceId, from as NSDate, to as NSDate)

        fetchAndIngest(deviceId: deviceId, from: from, to: to) { result in
            switch result {
            case .success(let count):
                completion(.success("Successfully fetched and saved \(count) sleep segments"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // Overloaded version of fetchAndIngest to support completion callback
    private func fetchAndIngest(
        deviceId: String,
        from: Date,
        to: Date,
        completion: @escaping (Swift.Result<Int, Error>) -> Void = { _ in }
    ) {
        source.fetchSleepSegments(deviceId: deviceId, from: from, to: to) { [weak self] result in
            guard let self else {
                completion(.failure(NSError(domain: "Polar360SleepIngestor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Self reference lost"])))
                return
            }

            switch result {
            case .failure(let err):
                NSLog("[P360Sleep] fetch failed for %@: %@", deviceId, err.localizedDescription)
                completion(.failure(err))
            case .success(let segments):
                guard !segments.isEmpty else {
                    NSLog("[P360Sleep] no segments to ingest for %@", deviceId)
                    completion(.success(0))
                    return
                }
                self.persist(segments: segments)
                completion(.success(segments.count))
            }
        }
    }

    // MARK: - Core ingestion pipeline

    private func fetchAndIngest(deviceId: String, from: Date, to: Date) {
        source.fetchSleepSegments(deviceId: deviceId, from: from, to: to) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                NSLog("[P360Sleep] fetch failed for %@: %@", deviceId, err.localizedDescription)
            case .success(let segments):
                guard !segments.isEmpty else {
                    NSLog("[P360Sleep] no segments to ingest for %@", deviceId)
                    return
                }
                self.persist(segments: segments)
            }
        }
    }

    /// Persist incoming segments into SleepSegmentEntity.
    /// Strategy:
    /// - For each sleep "day bucket", delete existing Polar360 segments
    ///   and re-insert the fresh ones (idempotent).
    private func persist(segments: [SleepSegment]) {
        let bg = bgContext
        let switcher = UserStoreSwitchCoordinator.shared
        switcher.withRead {
            bg.perform {
                let cal = Calendar.current
                
                // 1) Group by bucket date (use startOfDay for now; SleepRepository
                //    already applies its own "night window" logic).
                let grouped = Dictionary(grouping: segments) { (seg: SleepSegment) -> Date in
                    return cal.startOfDay(for: seg.end) // bucket by end date
                }
                
                for (bucket, segs) in grouped {
                    // 2) Delete previous Polar360 segments for this bucket.
                    let fetch = SleepSegmentEntity.fetchRequest()
                    fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "sleepDayStart == %@", bucket as NSDate),
                        NSPredicate(format: "sourceRaw == %d", SleepDataSource.ct360.rawValueInt)
                    ])
                    
                    do {
                        let existing = try bg.fetch(fetch)
                        for e in existing { bg.delete(e) }
                    } catch {
                        NSLog("[P360Sleep] delete existing error for bucket %@: %@", bucket as NSDate, error.localizedDescription)
                    }
                    
                    // 3) Insert new segments for this bucket.
                    for seg in segs {
                        guard seg.end > seg.start else { continue }
                        let obj = SleepSegmentEntity(context: bg)
                        obj.startDate = seg.start
                        obj.endDate   = seg.end
                        obj.stageRaw  = Int16(seg.stage.rawInt)
                        obj.sourceRaw = Int16(seg.source.rawValueInt)
                        obj.sleepDayStart = bucket
                    }
                }
                
                do {
                    try bg.save()
                    NSLog("[P360Sleep] persisted %d segments across %d buckets",
                          segments.count, grouped.keys.count)
                } catch {
                    NSLog("[P360Sleep] save error: %@", error.localizedDescription)
                }
                
                // Notify rest of app (BiometricsViewModel, HomeViewModel, Sleep screens).
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .ctSleepUpdated,
                        object: nil,
                        userInfo: ["source": SleepDataSource.ct360]
                    )
                }
            }
        }
    }
}

//
//  SleepRepository.swift
//  CalmTrade
//

import Foundation
import CoreData
import HealthKit

final class SleepRepository {

    static let shared = SleepRepository()

    private let calendar = Calendar.current
    private let healthStore = HKHealthStore()
    private let switcher = UserStoreSwitchCoordinator.shared

    private var viewContext: NSManagedObjectContext {
        CTMetricsStack.shared.container.viewContext
    }

    private func bgContext() -> NSManagedObjectContext {
        let ctx = CTMetricsStack.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }

    private init() {}

    // MARK: - PUBLIC API
    // ------------------------------------------------------------

    /// Insert staged segments coming from Polar360 or HealthKit.
    /// Repo writes ONLY; reading always goes through DTOs.
    func upsertSegments(_ segments: [SleepSegment]) throws {
        guard !segments.isEmpty else { return }

        let ctx = bgContext()

        try switcher.withRead {
            try ctx.performAndWait {

                let day = sleepDayStart(for: segments[0].start)
                let source = segments[0].source.rawValueInt16

                // Batch delete safely for this day+source
                let deleteReq: NSFetchRequest<NSFetchRequestResult> = SleepSegmentEntity.fetchRequest()
                deleteReq.predicate = NSPredicate(
                    format: "sleepDayStart == %@ AND sourceRaw == %d",
                    day as NSDate, source
                )

                let batch = NSBatchDeleteRequest(fetchRequest: deleteReq)
                batch.resultType = .resultTypeObjectIDs

                if let res = try ctx.execute(batch) as? NSBatchDeleteResult,
                   let ids = res.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                        into: [ctx, viewContext]
                    )
                }

                // Insert new segments atomically
                for seg in segments {
                    guard seg.end > seg.start else { continue }
                    let obj = SleepSegmentEntity(context: ctx)
                    obj.startDate = seg.start
                    obj.endDate   = seg.end
                    obj.stageRaw  = Int16(seg.stage.rawInt)
                    obj.sourceRaw = seg.source.rawValueInt16
                    obj.sleepDayStart = day
                }

                try ctx.save()
            }
        }
    }

    // MARK: - Unified Fetch (Polar360 > Apple Health)
    // ------------------------------------------------------------

    /// The ONE canonical source for sleep segments in the app.
    /// - First: repo segments from Core Data (Polar360 or others).
    /// - Fallback: HealthKit segments (synchronous).
    func unifiedSegments(from start: Date, to end: Date) -> [SleepSegment] {
        // 1) Repo (Core Data) first
        let local = loadLocalSegments(from: start, to: end)
        if !local.isEmpty {
            return unifyBySleepDay(local)
        }

        // 2) Synchronous HealthKit fallback.
        //    If HK is unavailable or times out, this returns [].
        let hk = hkSegmentsSync(from: start, to: end)
        if hk.isEmpty { return [] }
        return unifyBySleepDay(hk)
    }

    // MARK: - Load Local Segments (Core Data → DTO)
    private func loadLocalSegments(from start: Date, to end: Date) -> [SleepSegment] {
        let ctx = viewContext

        return switcher.withRead {
            var output: [SleepSegment] = []

            ctx.performAndWait {
                let req: NSFetchRequest<SleepSegmentEntity> = SleepSegmentEntity.fetchRequest()
                req.predicate = NSPredicate(
                    format: "startDate < %@ AND endDate > %@",
                    end as NSDate, start as NSDate
                )
                req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

                guard let rows = try? ctx.fetch(req) else { return }

                // Snapshot all values inside performAndWait – never leak NSManagedObject.
                for r in rows {
                    let stage = SleepStage.fromRaw(Int(r.stageRaw)) ?? .awake
                    let seg = SleepSegment(
                        stage: stage,
                        start: r.startDate,
                        end: r.endDate,
                        source: SleepDataSource(rawValueInt: Int(r.sourceRaw))
                    )
                    output.append(seg)
                }
            }

            return output
        }
    }

    // MARK: - HealthKit fallback (sync, background-only)
    /// Synchronous HealthKit fallback used ONLY when repo has no data.
    /// Must NEVER block main thread.
    private func hkSegmentsSync(from start: Date, to end: Date) -> [SleepSegment] {
        // Hard guard: never block main.
        if Thread.isMainThread {
            // If a caller ever hits this from main, we fail safe and return [].
            // All your current call sites are already on background queues.
            return []
        }

        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else { return [] }

        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let sem = DispatchSemaphore(value: 0)
        var output: [SleepSegment] = []

        let q = HKSampleQuery(
            sampleType: type,
            predicate: pred,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in

            var segs: [SleepSegment] = []

            if let items = samples as? [HKCategorySample] {
                segs.reserveCapacity(items.count)

                for s in items where s.endDate > s.startDate {
                    if let stage = SleepStage.fromHKValue(s.value) {
                        let st = max(s.startDate, start)
                        let en = min(s.endDate,   end)
                        if en > st {
                            segs.append(
                                SleepSegment(
                                    stage: stage,
                                    start: st,
                                    end: en,
                                    source: .appleHealth
                                )
                            )
                        }
                    }
                }
            }

            output = segs
            sem.signal()
        }

        healthStore.execute(q)

        // Wait (bounded) on the same background QoS thread that called unifiedSegments.
//        _ = sem.wait(timeout: .now() + 4)

        return output
    }

    // MARK: - Merge by Sleep Day (ct360 > HK)
    /// Bucket by "sleep day" and prioritize Polar360 over HK per bucket.
    private func unifyBySleepDay(_ segments: [SleepSegment]) -> [SleepSegment] {
        let grouped = Dictionary(grouping: segments) { seg in
            sleepDayStart(for: seg.start)
        }

        var out: [SleepSegment] = []

        for (_, daySegs) in grouped {
            let ct = daySegs.filter { $0.source == .ct360 }
            let hk = daySegs.filter { $0.source == .appleHealth }

            if !ct.isEmpty {
                out.append(contentsOf: ct)
            } else if !hk.isEmpty {
                out.append(contentsOf: hk)
            }
        }

        return out.sorted { $0.start < $1.start }
    }

    // MARK: - Utils
    func sleepDayStart(for date: Date) -> Date {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        return calendar.startOfDay(for: noon)
    }

    // MARK: - Latest Night (Unified)
    /// Single canonical entry point for "last night" sleep.
    /// This is what Home, Biometrics, SleepInsight & CalmScore should all use.
    func latestNight() -> (date: Date, segments: [SleepSegment], hours: Double)? {
        let now = Date()

        // Look back 72 hours to be safe; users may sync midday
        let start = now.addingTimeInterval(-72 * 3600)

        let all = unifiedSegments(from: start, to: now)
        guard !all.isEmpty else { return nil }

        // Group by sleep-day bucket
        let grouped = Dictionary(grouping: all) { seg in
            sleepDayStart(for: seg.start)
        }

        // Pick latest day
        guard let latestDay = grouped.keys.sorted().last,
              let daySegments = grouped[latestDay] else {
            return nil
        }

        let secs = SleepRepository.totalAsleepUnionSeconds(from: daySegments)
        return (date: latestDay, segments: daySegments, hours: secs / 3600.0)
    }

    // Used by HomeViewModel.latestNightBefore and BiometricsViewModel.latestNightBefore
    func latestNightBefore(date: Date) -> (date: Date, hours: Double)? {
        // Look 48h back from anchor for any segments
        let start = date.addingTimeInterval(-48 * 3600)
        let segs = unifiedSegments(from: start, to: date)
        guard let last = segs.last else { return nil }

        let bucket = sleepDayStart(for: last.start)
        let nextBucket = bucket.addingTimeInterval(24 * 3600)
        let nightSegs = unifiedSegments(from: bucket, to: nextBucket)
        let secs = nightSegs.reduce(0.0) {
            $0 + max(0.0, $1.end.timeIntervalSince($1.start))
        }
        return (bucket, secs / 3600.0)
    }

    private static func totalAsleepUnionSeconds(from segments: [SleepSegment]) -> TimeInterval {
        var intervals = segments
            .filter { $0.stage != .awake }
            .map { ($0.start, $0.end) }
            .sorted { $0.0 < $1.0 }

        var merged: [(Date, Date)] = []
        for (s, e) in intervals {
            guard s < e else { continue }
            if let last = merged.last, s <= last.1 {
                merged[merged.count - 1].1 = max(last.1, e)
            } else {
                merged.append((s, e))
            }
        }
        return merged.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) }
    }
}

// MARK: - SleepStage / SleepDataSource helpers

extension SleepStage {
    init?(rawValueInt: Int) {
        guard rawValueInt >= 0 && rawValueInt < SleepStage.displayOrder.count else { return nil }
        self = SleepStage.displayOrder[rawValueInt]
    }

    static func fromHKValue(_ raw: Int) -> SleepStage? {
        switch raw {
        case HKCategoryValueSleepAnalysis.awake.rawValue:          return .awake
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:      return .rem
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:     return .core
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:     return .deep
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return .core
        default:
            return nil
        }
    }
}

extension SleepDataSource {
    var rawValueInt16: Int16 { Int16(rawValueInt) }
}

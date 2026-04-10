//
//  SleepRepository.swift
//  CalmTrade
//

import Foundation
import CoreData
import HealthKit

struct SleepSessionSummary {
    let sessionStart: Date
    let sessionEnd: Date
    let totalInBedSeconds: TimeInterval
    let remSeconds: TimeInterval
    let coreSeconds: TimeInterval
    let deepSeconds: TimeInterval
    let awakeSeconds: TimeInterval
    let source: SleepDataSource
    let segments: [SleepSegment]
}

final class SleepRepository {

    static let shared = SleepRepository()

    private let calendar = Calendar.current
    private let healthStore = HKHealthStore()
    private let switcher = UserStoreSwitchCoordinator.shared
    private let sessionGapSeconds: TimeInterval = 90 * 60

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

    // MARK: - Debug logging
    /// Prints latest-night segments with per-segment duration and aggregate totals.
    /// Use this to compare what the app is calculating vs. what should be displayed.
    func debugLogLatestNightSegments(context: String = "SleepRepository") {
        guard let night = latestNight() else {
            debugPrint("[\(context)] No latest night found")
            return
        }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        let ordered = night.segments.sorted { $0.start < $1.start }
        let totalInBedSeconds = ordered.reduce(0.0) { acc, seg in
            acc + max(0.0, seg.end.timeIntervalSince(seg.start))
        }
        let totalAsleepSeconds = SleepRepository.totalAsleepUnionSeconds(from: ordered)

        debugPrint("========== [\(context)] Sleep Segments ==========")
        debugPrint("Night bucket: \(dateFmt.string(from: night.date))")
        debugPrint("Segment count: \(ordered.count)")
        for (idx, seg) in ordered.enumerated() {
            let durationSec = max(0.0, seg.end.timeIntervalSince(seg.start))
            let durationMin = Int((durationSec / 60.0).rounded())
            debugPrint(
                "[\(idx)] stage=\(seg.stage) source=\(seg.source) start=\(dateFmt.string(from: seg.start)) end=\(dateFmt.string(from: seg.end)) duration=\(durationMin)m"
            )
        }
        debugPrint("Total asleep (union): \(String(format: "%.2f", totalAsleepSeconds / 3600.0)) h")
        debugPrint("Total in bed (sum): \(String(format: "%.2f", totalInBedSeconds / 3600.0)) h")
        debugPrint("Canonical latestNight.hours: \(String(format: "%.2f", night.hours)) h")
        debugPrint("===============================================")
    }

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

    /// Canonical sessionized sleep summaries derived from unified segments.
    func unifiedSessions(from start: Date, to end: Date) -> [SleepSessionSummary] {
        let segs = unifiedSegments(from: start, to: end).sorted { $0.start < $1.start }
        guard !segs.isEmpty else { return [] }

        let sessions = SleepRepository.groupIntoSessions(segs, sessionGap: sessionGapSeconds)
        var out: [SleepSessionSummary] = []
        out.reserveCapacity(sessions.count)

        for group in sessions {
            guard let first = group.first, let last = group.last else { continue }

            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var deep: TimeInterval = 0
            var awake: TimeInterval = 0

            for seg in group {
                let dur = max(0, seg.end.timeIntervalSince(seg.start))
                switch seg.stage {
                case .rem: rem += dur
                case .core: core += dur
                case .deep: deep += dur
                case .awake: awake += dur
                }
            }

            let source: SleepDataSource = {
                if group.contains(where: { $0.source == .ct360 }) { return .ct360 }
                if group.contains(where: { $0.source == .appleHealth }) { return .appleHealth }
                return group.first?.source ?? .appleHealth
            }()

            out.append(
                SleepSessionSummary(
                    sessionStart: first.start,
                    sessionEnd: last.end,
                    totalInBedSeconds: SleepRepository.totalInBedSeconds(from: group),
                    remSeconds: rem,
                    coreSeconds: core,
                    deepSeconds: deep,
                    awakeSeconds: awake,
                    source: source,
                    segments: group
                )
            )
        }

        return out
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

        // Use latest continuous sleep session (supports cross-midnight nights).
        let sessions = SleepRepository.groupIntoSessions(
            all.sorted { $0.start < $1.start },
            sessionGap: sessionGapSeconds
        )
        guard let latestSession = sessions.last,
              let sessionEnd = latestSession.map(\.end).max() else { return nil }

        let secs = SleepRepository.totalInBedSeconds(from: latestSession)
        let day = calendar.startOfDay(for: sessionEnd)
        return (date: day, segments: latestSession, hours: secs / 3600.0)
    }

    /// Source-scoped latest night.
    /// If provided, only that source is considered for session building.
    func latestNight(preferredSource: SleepDataSource) -> (date: Date, segments: [SleepSegment], hours: Double)? {
        let now = Date()
        let start = now.addingTimeInterval(-72 * 3600)

        var all = loadLocalSegments(from: start, to: now).filter { $0.source == preferredSource }
        if all.isEmpty, preferredSource == .appleHealth {
            all = hkSegmentsSync(from: start, to: now)
        }
        guard !all.isEmpty else { return nil }

        let sessions = SleepRepository.groupIntoSessions(
            all.sorted { $0.start < $1.start },
            sessionGap: sessionGapSeconds
        )
        guard let latestSession = sessions.last,
              let sessionEnd = latestSession.map(\.end).max() else { return nil }

        let secs = SleepRepository.totalInBedSeconds(from: latestSession)
        let day = calendar.startOfDay(for: sessionEnd)
        return (date: day, segments: latestSession, hours: secs / 3600.0)
    }

    // Used by HomeViewModel.latestNightBefore and BiometricsViewModel.latestNightBefore
    func latestNightBefore(date: Date) -> (date: Date, hours: Double)? {
        // Look back far enough to include cross-midnight sessions.
        let start = date.addingTimeInterval(-72 * 3600)
        let segs = unifiedSegments(from: start, to: date)
        guard !segs.isEmpty else { return nil }

        let sessions = SleepRepository.groupIntoSessions(
            segs.sorted { $0.start < $1.start },
            sessionGap: sessionGapSeconds
        )
        guard let latestSession = sessions.last,
              let sessionEnd = latestSession.map(\.end).max() else { return nil }

        let secs = SleepRepository.totalInBedSeconds(from: latestSession)
        let day = calendar.startOfDay(for: sessionEnd)
        return (day, secs / 3600.0)
    }

    /// Source-scoped latest night before a given date.
    func latestNightBefore(date: Date, preferredSource: SleepDataSource) -> (date: Date, hours: Double)? {
        let start = date.addingTimeInterval(-72 * 3600)

        var segs = loadLocalSegments(from: start, to: date).filter { $0.source == preferredSource }
        if segs.isEmpty, preferredSource == .appleHealth {
            segs = hkSegmentsSync(from: start, to: date)
        }
        guard !segs.isEmpty else { return nil }

        let sessions = SleepRepository.groupIntoSessions(
            segs.sorted { $0.start < $1.start },
            sessionGap: sessionGapSeconds
        )
        guard let latestSession = sessions.last,
              let sessionEnd = latestSession.map(\.end).max() else { return nil }

        let secs = SleepRepository.totalInBedSeconds(from: latestSession)
        let day = calendar.startOfDay(for: sessionEnd)
        return (day, secs / 3600.0)
    }

    private static func groupIntoSessions(_ segments: [SleepSegment], sessionGap: TimeInterval) -> [[SleepSegment]] {
        guard !segments.isEmpty else { return [] }

        var sessions: [[SleepSegment]] = []
        for seg in segments {
            if var lastSession = sessions.last,
               let tail = lastSession.last,
               seg.start.timeIntervalSince(tail.end) <= sessionGap {
                lastSession.append(seg)
                sessions[sessions.count - 1] = lastSession
            } else {
                sessions.append([seg])
            }
        }
        return sessions
    }

    private static func totalInBedSeconds(from segments: [SleepSegment]) -> TimeInterval {
        segments.reduce(0.0) { acc, seg in
            acc + max(0.0, seg.end.timeIntervalSince(seg.start))
        }
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

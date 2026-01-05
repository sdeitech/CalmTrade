//
//  CalmScoreStore.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/09/25.
//

import Foundation
import CoreData

// MARK: - Time Scales

enum CalmTimeScale: CaseIterable {
    case minute, hour, day, week, month, sixMonths, year

    var bucketComponent: Calendar.Component {
        switch self {
        case .minute:    return .minute
        case .hour:      return .hour
        case .day:       return .day
        case .week:      return .weekOfYear
        case .month:     return .month
        case .sixMonths: return .weekOfYear
        case .year:      return .month
        }
    }

    var pageCount: Int {
        switch self {
        case .minute:    return 120
        case .hour:      return 72
        case .day:       return 120
        case .week:      return 104
        case .month:     return 60
        case .sixMonths: return 26
        case .year:      return 12
        }
    }
}

// MARK: - Models

struct CalmAggregate {
    let bucketStart: Date
    let avg: Double
    let count: Int
}

struct CalmScoreSampleRow: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let source: String?
}

// MARK: - CalmScoreStore

final class CalmScoreStore {

    static let shared = CalmScoreStore()
    private let stack = CoreDataStack.shared
    private let cal = Calendar.current
    private let switchCoordinator = UserStoreSwitchCoordinator.shared

    private var userId: String {
        SessionManager.shared.current?.id ?? "_anonymous"
    }

    // Helper predicate that is safe even if the model lacks userId
    private func safeUserPredicate(in context: NSManagedObjectContext) -> NSPredicate? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CalmScoreSample", in: context),
              entity.attributesByName.keys.contains("userId") else {
            return nil
        }
        return NSPredicate(format: "userId == %@", userId)
    }

    // MARK: - Save (dedup by minute)
    func save(value: Double, at date: Date = Date(), source: String? = nil) {
        switchCoordinator.withRead {
            let ctx = stack.newBackgroundContext()
            ctx.perform {
                let rounded = self.cal.date(bySetting: .second, value: 0, of: date) ?? date

                let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
                var predicates: [NSPredicate] = [NSPredicate(format: "timestamp == %@", rounded as NSDate)]
                if let userPred = self.safeUserPredicate(in: ctx) {
                    predicates.append(userPred)
                }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                req.fetchLimit = 1

                let existing = (try? ctx.fetch(req))?.first
                let obj = existing ?? CalmScoreSample(context: ctx)
                obj.timestamp = rounded
                obj.value = value
                obj.source = source
                if obj.responds(to: #selector(setter: CalmScoreSample.userId)) {
                    obj.userId = self.userId
                }

                do {
                    try ctx.save()
                } catch {
                    NSLog("[CalmScoreStore] Save error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Graph Series (THREAD-SAFE)
    func fetchSeries(scale: CalmTimeScale, start: Date, end: Date) -> [CalmAggregate] {
        switchCoordinator.withRead {
            let ctx = stack.newBackgroundContext()
            var result: [CalmAggregate] = []

            ctx.performAndWait {
                let s = truncate(start, to: scale)
                let e = truncate(end,   to: scale)

                let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
                var predicates: [NSPredicate] = [
                    NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", start as NSDate, end as NSDate)
                ]
                if let userPred = safeUserPredicate(in: ctx) { predicates.append(userPred) }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

                guard let rows = try? ctx.fetch(req) else { return }

                var buckets: [Date: (sum: Double, count: Int)] = [:]
                for r in rows {
                    guard let ts = r.timestamp else { continue }
                    let v = r.value
                    let bucket = truncate(ts, to: scale)
                    let cur = buckets[bucket] ?? (0, 0)
                    buckets[bucket] = (cur.sum + v, cur.count + 1)
                }

                var cursor = s
                while cursor <= e {
                    if let b = buckets[cursor] {
                        result.append(.init(bucketStart: cursor,
                                            avg: b.sum / Double(max(1, b.count)),
                                            count: b.count))
                    }
                    guard let next = cal.date(byAdding: scale.bucketComponent, value: 1, to: cursor) else { break }
                    cursor = next
                }
            }

            return result
        }
    }

    // MARK: - Daily averages for gauges
    func fetchDailyAverages(limit: Int = 30, before day: Date = Date()) -> [CalmAggregate] {
        let end = truncate(day, to: .day)
        let start = cal.date(byAdding: .day, value: -(limit - 1), to: end)!
        let series = fetchSeries(scale: .day, start: start, end: end)
        return series.reversed()
    }

    // MARK: - Full log
    func fetchAllSamples(limit: Int? = nil, before: Date? = nil, ascending: Bool = true) -> [CalmScoreSampleRow] {
        switchCoordinator.withRead {
            let ctx = stack.newBackgroundContext()
            var rowsOut: [CalmScoreSampleRow] = []
            let end = before ?? Date()

            ctx.performAndWait {
                let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
                var predicates: [NSPredicate] = [NSPredicate(format: "timestamp <= %@", end as NSDate)]
                if let userPred = safeUserPredicate(in: ctx) { predicates.append(userPred) }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
                if let limit { req.fetchLimit = limit }

                guard let rows = try? ctx.fetch(req) else { return }
                var tmp: [CalmScoreSampleRow] = []
                for r in rows {
                    guard let ts = r.timestamp else { continue }
                    let value = r.value
                    let source = r.source
                    tmp.append(CalmScoreSampleRow(timestamp: ts, value: value, source: source))
                }
                rowsOut = tmp
            }
            return rowsOut
        }
    }

    // MARK: - Hour bucketed ranges (for charts)
    func fetchHourBucketedRanges(
        end: Date = Date(),
        bucketMinutes: Int = 3,
        carryForward: Bool = true
    ) -> (ranges: [ClosedRange<Double>?], startOfHour: Date, filledCount: Int) {

        precondition(bucketMinutes > 0 && 60 % bucketMinutes == 0, "bucketMinutes must divide 60")

        return switchCoordinator.withRead {
            let ctx = stack.newBackgroundContext()
            var result: [ClosedRange<Double>?] = Array(repeating: nil, count: 60 / bucketMinutes)
            var anchor = end
            var filledCount = 0

            ctx.performAndWait {
                let cal = Calendar.current
                guard let hourInterval = cal.dateInterval(of: .hour, for: end) else { return }
                let startOfHour = hourInterval.start
                let nextHourStart = hourInterval.end
                anchor = startOfHour

                let minuteOfHour = cal.component(.minute, from: end)
                let curIndex = minuteOfHour / bucketMinutes
                filledCount = min(result.count, curIndex + 1)

                let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
                var predicates: [NSPredicate] = [
                    NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfHour as NSDate, nextHourStart as NSDate)
                ]
                if let userPred = safeUserPredicate(in: ctx) { predicates.append(userPred) }
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

                guard let rows = try? ctx.fetch(req) else { return }

                struct Agg { var lo: Double; var hi: Double }
                var buckets: [Int: Agg] = [:]

                for r in rows {
                    guard let ts = r.timestamp else { continue }
                    let raw = r.value
                    let val = max(0, min(100, raw))
                    let secs = ts.timeIntervalSince(startOfHour)
                    guard secs >= 0, secs < 3600 else { continue }

                    let minute = Int(secs / 60.0)
                    let idx = min(result.count - 1, minute / bucketMinutes)
                    if let a = buckets[idx] {
                        buckets[idx] = Agg(lo: min(a.lo, val), hi: max(a.hi, val))
                    } else {
                        buckets[idx] = Agg(lo: val, hi: val)
                    }
                }

                for i in 0..<result.count {
                    if let a = buckets[i] {
                        let lo = a.lo
                        let hi = max(lo + 0.75, a.hi)
                        result[i] = lo...hi
                    } else if carryForward, i > 0, i < filledCount, let prev = result[i - 1] {
                        let mid = (prev.lowerBound + prev.upperBound) * 0.5
                        result[i] = max(0, mid - 0.4)...min(100, mid + 0.4)
                    } else {
                        result[i] = nil
                    }
                }
            }

            return (result, anchor, filledCount)
        }
    }

    // MARK: - Date helpers
    func truncate(_ date: Date, to scale: CalmTimeScale) -> Date {
        switch scale {
        case .minute:
            return cal.date(bySetting: .second, value: 0, of: date) ?? date
        case .hour:
            return cal.date(bySetting: .minute, value: 0, of: date) ?? date
        case .day:
            return cal.startOfDay(for: date)
        case .week, .sixMonths:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return cal.date(from: comps) ?? date
        case .month, .year:
            let comps = cal.dateComponents([.year, .month], from: date)
            return cal.date(from: comps) ?? date
        }
    }
    
    func purgeOldSessionCache() {
        switchCoordinator.withRead {
            let ctx = stack.newBackgroundContext()
            ctx.perform {
                let req: NSFetchRequest<CalmScoreSample> = CalmScoreSample.fetchRequest()
                if let userPred = self.safeUserPredicate(in: ctx) {
                    req.predicate = NSCompoundPredicate(notPredicateWithSubpredicate: userPred)
                }
                if let rows = try? ctx.fetch(req) {
                    for obj in rows { ctx.delete(obj) }
                }
                try? ctx.save()
            }
        }
    }
}

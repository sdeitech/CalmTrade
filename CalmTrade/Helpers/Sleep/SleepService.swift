//
//  SleepService.swift
//  CalmTrade
//
//  Created by Anas Parekh on 17/11/25.
//

import HealthKit
import Foundation

final class SleepService {
    static let shared = SleepService()

    private let repo = CTMetricsRepository.shared
    private let healthStore = HKHealthStore()

    /// Computes total sleep hours for the last night using repo → HK fallback.
    func latestSleepHours(completion: @escaping (Double?) -> Void) {
        // 1. Define last-night window (customizable)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let start = yesterday
        let end   = today

        // 2. Try repo first
        let repoSegs = repoSegments(from: start, to: end)
        if !repoSegs.isEmpty {
            let seconds = SleepService.totalAsleepUnionSeconds(from: repoSegs)
            completion(seconds / 3600.0)
            return
        }

        // 3. HealthKit fallback
        hkSegments(from: start, to: end) { hkSegs in
            let seconds = SleepService.totalAsleepUnionSeconds(from: hkSegs)
            completion(seconds / 3600.0)
        }
    }

    private func repoSegments(from: Date, to: Date) -> [SleepSegment] {
        return [] // until repo sleep is implemented
    }

    // COPY THE SAME IMPLEMENTATIONS FROM SleepInsightViewModel:
    private func hkSegments(from start: Date, to end: Date,
                            completion: @escaping ([SleepSegment]) -> Void) {
        // If Health isn’t available or authorized, return empty (don’t block UI).
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([]); return
        }

        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: type,
                                  predicate: pred,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self, let items = samples as? [HKCategorySample] else {
                completion([]); return
            }

            var out: [SleepSegment] = []
            out.reserveCapacity(items.count)

            for s in items where s.endDate > s.startDate {
                // Map HK -> SleepStage
                let stage: SleepStage?
                switch s.value {
                case HKCategoryValueSleepAnalysis.awake.rawValue:          stage = .awake
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:      stage = .rem
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:     stage = .core
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:     stage = .deep
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stage = .core   // reasonable default, matches Health behavior
                default:
                    stage = nil     // ignore .inBed, etc., for stage chart
                }
                guard let stg = stage else { continue }

                // Clamp to requested window (HK can return a bit wider)
                let st = max(s.startDate, start)
                let en = min(s.endDate,   end)
                if en > st { out.append(SleepSegment(stage: stg, start: st, end: en)) }
            }

            // Return on a user-initiated queue to keep downstream work snappy
            DispatchQueue.global(qos: .userInitiated).async {
                completion(out)
            }
        }

        healthStore.execute(query)
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
